#!/usr/bin/env python3
"""
Differential Privacy Query Executor using IBM diffprivlib

This script executes SQL aggregate queries with differential privacy guarantees
using the diffprivlib library. It accepts JSON input and returns JSON output.

Usage:
    python3 dp_executor.py <input_json>

Input JSON format:
{
    "query": "SELECT COUNT(*) FROM table",
    "data": [[val1, val2, ...], [val1, val2, ...], ...],  # 2D array of data
    "columns": ["col1", "col2", ...],
    "epsilon": 0.1,
    "delta": 1e-5,
    "bounds": {"col1": [min, max], "col2": [min, max], ...}  # optional
}

Output JSON format:
{
    "success": true,
    "result": {"count": 1234},
    "epsilon_consumed": 0.1,
    "delta": 1e-5,
    "mechanism": "laplace",
    "noise_scale": 10.0,
    "execution_time_ms": 150,
    "metadata": {...}
}
"""

import sys
import json
import time
import re
from typing import Dict, Any, List, Tuple, Optional
import pandas as pd
import numpy as np
from diffprivlib import tools as dp_tools
from diffprivlib.mechanisms import Laplace, Gaussian


class DPQueryExecutor:
    """Executes SQL queries with differential privacy using diffprivlib"""

    def __init__(self, data: List[List], columns: List[str], epsilon: float, delta: float = 1e-5):
        """
        Initialize the DP query executor

        Args:
            data: 2D array of data values
            columns: Column names
            epsilon: Privacy budget (epsilon)
            delta: Privacy parameter delta for (epsilon, delta)-DP
        """
        self.df = pd.DataFrame(data, columns=columns)
        self.epsilon = epsilon
        self.delta = delta
        self.mechanism_used = None
        self.noise_scale = None

    def parse_query(self, query: str) -> Dict[str, Any]:
        """
        Parse SQL query to extract operation, column, and filters

        Supported queries:
        - SELECT COUNT(*) FROM table
        - SELECT SUM(column) FROM table
        - SELECT AVG(column) FROM table
        - SELECT MIN(column) FROM table
        - SELECT MAX(column) FROM table

        With optional WHERE clauses (simple equality only for MVP)
        """
        query = query.strip().upper()

        # Extract aggregate function
        agg_match = re.search(r'(COUNT|SUM|AVG|MEAN|MIN|MAX)\s*\(([^)]*)\)', query)
        if not agg_match:
            raise ValueError(f"Unsupported query: {query}. Must contain COUNT, SUM, AVG, MIN, or MAX")

        operation = agg_match.group(1).lower()
        column = agg_match.group(2).strip()

        # Handle COUNT(*) or COUNT(column)
        if operation == 'count':
            if column == '*' or column == '':
                column = None  # Count rows
            else:
                column = column.strip()

        # Extract WHERE conditions (simple parsing for MVP)
        where_conditions = []
        where_match = re.search(r'WHERE\s+(.+?)(?:GROUP BY|ORDER BY|LIMIT|$)', query, re.IGNORECASE)
        if where_match:
            where_clause = where_match.group(1).strip()
            # Simple parsing: col = value (only equality for MVP)
            for condition in where_clause.split('AND'):
                condition = condition.strip()
                eq_match = re.search(r'(\w+)\s*=\s*[\'"]?([^\'"]+)[\'"]?', condition, re.IGNORECASE)
                if eq_match:
                    col_name = eq_match.group(1).strip().lower()
                    value = eq_match.group(2).strip()
                    where_conditions.append((col_name, value))

        return {
            'operation': operation,
            'column': column.lower() if column else None,
            'where': where_conditions
        }

    def apply_filters(self, where_conditions: List[Tuple[str, str]]) -> pd.DataFrame:
        """Apply WHERE conditions to dataframe"""
        filtered_df = self.df.copy()

        for col_name, value in where_conditions:
            if col_name in filtered_df.columns:
                # Try numeric comparison first, then string
                try:
                    numeric_value = float(value)
                    filtered_df = filtered_df[filtered_df[col_name] == numeric_value]
                except ValueError:
                    filtered_df = filtered_df[filtered_df[col_name].astype(str) == value]

        return filtered_df

    def execute_count(self, column: Optional[str], where_conditions: List) -> float:
        """
        Execute COUNT query with differential privacy

        Uses Laplace mechanism for integer counts
        """
        df = self.apply_filters(where_conditions)

        # True count
        if column is None:
            true_count = len(df)
        else:
            true_count = df[column].notna().sum()

        # Apply DP noise using Laplace mechanism
        # For COUNT, sensitivity = 1 (adding/removing one row changes count by 1)
        sensitivity = 1.0
        laplace = Laplace(epsilon=self.epsilon, sensitivity=sensitivity)

        # Add noise and clip to non-negative
        dp_count = laplace.randomise(float(true_count))
        dp_count = max(0, round(dp_count))  # Counts must be non-negative integers

        self.mechanism_used = 'laplace'
        self.noise_scale = sensitivity / self.epsilon

        return dp_count

    def execute_sum(self, column: str, where_conditions: List, bounds: Optional[Tuple[float, float]] = None) -> float:
        """
        Execute SUM query with differential privacy

        Requires bounds on the column values for bounded DP
        """
        df = self.apply_filters(where_conditions)

        if column not in df.columns:
            raise ValueError(f"Column '{column}' not found in dataset")

        # Get data
        data = df[column].dropna().values

        if len(data) == 0:
            return 0.0

        # Determine bounds
        if bounds is None:
            # Auto-determine bounds (less private but more accurate)
            lower = float(data.min())
            upper = float(data.max())
        else:
            lower, upper = bounds

        # Clip values to bounds
        clipped_data = np.clip(data, lower, upper)
        true_sum = float(clipped_data.sum())

        # Sensitivity for bounded sum = (upper - lower) * n_max
        # For MVP, assume n_max = len(df) (worst case)
        sensitivity = (upper - lower) * len(df)

        # Apply Laplace noise
        laplace = Laplace(epsilon=self.epsilon, sensitivity=sensitivity)
        dp_sum = laplace.randomise(true_sum)

        self.mechanism_used = 'laplace'
        self.noise_scale = sensitivity / self.epsilon

        return dp_sum

    def execute_avg(self, column: str, where_conditions: List, bounds: Optional[Tuple[float, float]] = None) -> float:
        """
        Execute AVG query with differential privacy

        Uses composition: AVG = SUM / COUNT (consumes 2*epsilon)
        """
        df = self.apply_filters(where_conditions)

        if column not in df.columns:
            raise ValueError(f"Column '{column}' not found in dataset")

        data = df[column].dropna().values

        if len(data) == 0:
            return 0.0

        # Determine bounds
        if bounds is None:
            lower = float(data.min())
            upper = float(data.max())
        else:
            lower, upper = bounds

        # Clip values
        clipped_data = np.clip(data, lower, upper)

        # Use diffprivlib's mean function
        dp_avg = dp_tools.mean(clipped_data, epsilon=self.epsilon, bounds=(lower, upper))

        self.mechanism_used = 'laplace'
        # Sensitivity for bounded mean
        sensitivity = (upper - lower) / len(data)
        self.noise_scale = sensitivity / self.epsilon

        return float(dp_avg)

    def execute_min(self, column: str, where_conditions: List, bounds: Optional[Tuple[float, float]] = None) -> float:
        """
        Execute MIN query with differential privacy

        Uses exponential mechanism
        """
        df = self.apply_filters(where_conditions)

        if column not in df.columns:
            raise ValueError(f"Column '{column}' not found in dataset")

        data = df[column].dropna().values

        if len(data) == 0:
            return 0.0

        # Determine bounds
        if bounds is None:
            lower = float(data.min())
            upper = float(data.max())
        else:
            lower, upper = bounds

        # Clip values
        clipped_data = np.clip(data, lower, upper)

        # For MIN, use Laplace mechanism with sensitivity = range
        true_min = float(clipped_data.min())
        sensitivity = upper - lower

        laplace = Laplace(epsilon=self.epsilon, sensitivity=sensitivity)
        dp_min = laplace.randomise(true_min)
        dp_min = np.clip(dp_min, lower, upper)  # Clip to valid range

        self.mechanism_used = 'laplace'
        self.noise_scale = sensitivity / self.epsilon

        return float(dp_min)

    def execute_max(self, column: str, where_conditions: List, bounds: Optional[Tuple[float, float]] = None) -> float:
        """
        Execute MAX query with differential privacy
        """
        df = self.apply_filters(where_conditions)

        if column not in df.columns:
            raise ValueError(f"Column '{column}' not found in dataset")

        data = df[column].dropna().values

        if len(data) == 0:
            return 0.0

        # Determine bounds
        if bounds is None:
            lower = float(data.min())
            upper = float(data.max())
        else:
            lower, upper = bounds

        # Clip values
        clipped_data = np.clip(data, lower, upper)

        # For MAX, use Laplace mechanism with sensitivity = range
        true_max = float(clipped_data.max())
        sensitivity = upper - lower

        laplace = Laplace(epsilon=self.epsilon, sensitivity=sensitivity)
        dp_max = laplace.randomise(true_max)
        dp_max = np.clip(dp_max, lower, upper)

        self.mechanism_used = 'laplace'
        self.noise_scale = sensitivity / self.epsilon

        return float(dp_max)

    def execute(self, query: str, bounds: Optional[Dict[str, Tuple[float, float]]] = None) -> Dict[str, Any]:
        """
        Execute SQL query with differential privacy

        Returns:
            Dictionary with DP result and metadata
        """
        start_time = time.time()

        # Parse query
        parsed = self.parse_query(query)
        operation = parsed['operation']
        column = parsed['column']
        where_conditions = parsed['where']

        # Get bounds for column if specified
        col_bounds = None
        if bounds and column and column in bounds:
            col_bounds = tuple(bounds[column])

        # Execute based on operation
        if operation == 'count':
            result_value = self.execute_count(column, where_conditions)
            result_key = 'count'
        elif operation == 'sum':
            result_value = self.execute_sum(column, where_conditions, col_bounds)
            result_key = 'sum'
        elif operation in ['avg', 'mean']:
            result_value = self.execute_avg(column, where_conditions, col_bounds)
            result_key = 'average'
        elif operation == 'min':
            result_value = self.execute_min(column, where_conditions, col_bounds)
            result_key = 'min'
        elif operation == 'max':
            result_value = self.execute_max(column, where_conditions, col_bounds)
            result_key = 'max'
        else:
            raise ValueError(f"Unsupported operation: {operation}")

        execution_time_ms = int((time.time() - start_time) * 1000)

        return {
            'success': True,
            'result': {result_key: result_value},
            'epsilon_consumed': self.epsilon,
            'delta': self.delta,
            'mechanism': self.mechanism_used,
            'noise_scale': self.noise_scale,
            'execution_time_ms': execution_time_ms,
            'metadata': {
                'operation': operation,
                'column': column,
                'where_conditions': where_conditions,
                'num_rows_processed': len(self.df)
            }
        }


def main():
    """Main entry point for CLI execution"""
    if len(sys.argv) < 2:
        print(json.dumps({
            'success': False,
            'error': 'Missing input JSON argument'
        }))
        sys.exit(1)

    try:
        # Parse input JSON
        input_data = json.loads(sys.argv[1])

        # Extract parameters
        query = input_data['query']
        data = input_data['data']
        columns = input_data['columns']
        epsilon = input_data.get('epsilon', 0.1)
        delta = input_data.get('delta', 1e-5)
        bounds = input_data.get('bounds', None)

        # Create executor and run query
        executor = DPQueryExecutor(data, columns, epsilon, delta)
        result = executor.execute(query, bounds)

        # Output result as JSON
        print(json.dumps(result))
        sys.exit(0)

    except Exception as e:
        # Return error as JSON
        error_result = {
            'success': False,
            'error': str(e),
            'error_type': type(e).__name__
        }
        print(json.dumps(error_result))
        sys.exit(1)


if __name__ == '__main__':
    main()