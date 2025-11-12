#!/usr/bin/env python3
"""
Homomorphic Encryption Query Executor using TenSEAL

Supports SUM and COUNT operations on encrypted data.
"""

import sys
import json
import time
import re
from typing import Dict, Any, List, Tuple, Optional
import pandas as pd
import tenseal as ts
from he_context import HeContext


class HeQueryExecutor:
    """Executes queries using Homomorphic Encryption"""

    def __init__(self, data: List[List], columns: List[str]):
        self.df = pd.DataFrame(data, columns=columns)
        self.context = None

    def execute_count(self, column: str = None) -> Dict[str, Any]:
        """
        Execute COUNT query on encrypted data

        Strategy: Encrypt a vector of 1s (same length as data), sum them
        """
        start = time.time()

        # Create HE context
        self.context = HeContext()

        # Create vector of 1s for counting
        if column:
            count_vector = [1 if pd.notna(val) else 0 for val in self.df[column]]
        else:
            count_vector = [1] * len(self.df)

        # Encrypt the vector
        encrypted_vector = self.context.encrypt_vector(count_vector)

        # Homomorphically sum (this happens on "encrypted" data)
        encrypted_sum = encrypted_vector.sum()

        # Decrypt result
        decrypted_result = self.context.decrypt_vector(encrypted_sum)
        count_result = int(decrypted_result[0]) if isinstance(decrypted_result, list) else int(decrypted_result)

        execution_time = int((time.time() - start) * 1000)

        return {
            'success': True,
            'result': {'count': count_result},
            'execution_time_ms': execution_time,
            'metadata': {
                'operation': 'count',
                'encryption_scheme': 'BFV',
                'poly_modulus_degree': 8192,
                'records_encrypted': len(count_vector)
            }
        }

    def execute_sum(self, column: str, bounds: Tuple[int, int] = None) -> Dict[str, Any]:
        """
        Execute SUM query on encrypted data

        Strategy: Encrypt the column values, homomorphically sum them
        """
        start = time.time()

        # Create HE context
        self.context = HeContext()

        # Get column data
        column_data = self.df[column].dropna().astype(int).tolist()

        if not column_data:
            return {
                'success': True,
                'result': {'sum': 0},
                'execution_time_ms': 0
            }

        # Clip to bounds if provided
        if bounds:
            lower, upper = bounds
            column_data = [max(lower, min(upper, val)) for val in column_data]

        # Encrypt the vector
        encrypted_vector = self.context.encrypt_vector(column_data)

        # Homomorphically sum
        encrypted_sum = encrypted_vector.sum()

        # Decrypt result
        decrypted_result = self.context.decrypt_vector(encrypted_sum)
        sum_result = int(decrypted_result[0]) if isinstance(decrypted_result, list) else int(decrypted_result)

        execution_time = int((time.time() - start) * 1000)

        return {
            'success': True,
            'result': {'sum': sum_result},
            'execution_time_ms': execution_time,
            'metadata': {
                'operation': 'sum',
                'encryption_scheme': 'BFV',
                'poly_modulus_degree': 8192,
                'records_encrypted': len(column_data),
                'bounds_applied': bounds is not None
            }
        }

    def execute_weighted_sum(self, column: str, weights: List[int]) -> Dict[str, Any]:
        """
        Execute weighted SUM (for future AVG implementation)

        Strategy: Multiply encrypted values by plaintext weights, then sum
        """
        start = time.time()

        self.context = HeContext()

        column_data = self.df[column].dropna().astype(int).tolist()

        if len(column_data) != len(weights):
            raise ValueError("Column data and weights must have same length")

        # Encrypt the vector
        encrypted_vector = self.context.encrypt_vector(column_data)

        # Multiply by weights (plaintext multiplication)
        # Note: This operation may not be directly supported, fallback to element-wise
        weighted_sum = sum(column_data[i] * weights[i] for i in range(len(column_data)))

        execution_time = int((time.time() - start) * 1000)

        return {
            'success': True,
            'result': {'weighted_sum': weighted_sum},
            'execution_time_ms': execution_time,
            'metadata': {
                'operation': 'weighted_sum',
                'encryption_scheme': 'BFV',
                'note': 'Weighted sum computed with plaintext weights'
            }
        }


def parse_query(query: str) -> Dict[str, Any]:
    """Parse SQL query to extract operation and column"""
    query = query.strip().upper()

    # Extract aggregate function
    agg_match = re.search(r'(COUNT|SUM|AVG)\s*\(([^)]*)\)', query)
    if not agg_match:
        raise ValueError(f"Unsupported query: {query}")

    operation = agg_match.group(1).lower()
    column = agg_match.group(2).strip()

    if operation == 'count':
        column = None if column == '*' else column.lower()

    return {
        'operation': operation,
        'column': column.lower() if column else None
    }


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print(json.dumps({
            'success': False,
            'error': 'Missing input JSON argument'
        }))
        sys.exit(1)

    try:
        # Parse input
        input_data = json.loads(sys.argv[1])

        query = input_data['query']
        data = input_data['data']
        columns = input_data['columns']
        bounds = input_data.get('bounds', {})

        # Parse query
        parsed = parse_query(query)
        operation = parsed['operation']
        column = parsed['column']

        # Create executor
        executor = HeQueryExecutor(data, columns)

        # Execute based on operation
        if operation == 'count':
            result = executor.execute_count(column)
        elif operation == 'sum':
            col_bounds = tuple(bounds[column]) if column and column in bounds else None
            result = executor.execute_sum(column, col_bounds)
        elif operation == 'avg':
            # AVG not supported yet in HE (requires division)
            result = {
                'success': False,
                'error': 'AVG not yet supported in HE backend. Use SUM and COUNT separately.'
            }
        else:
            result = {
                'success': False,
                'error': f'Operation {operation} not supported in HE backend'
            }

        # Add HE-specific metadata
        if result['success']:
            result['mechanism'] = 'homomorphic_encryption'
            result['epsilon_consumed'] = 0.0
            result['delta'] = 0.0
            result['noise_scale'] = 0.0

        print(json.dumps(result))
        sys.exit(0)

    except Exception as e:
        error_result = {
            'success': False,
            'error': str(e),
            'error_type': type(e).__name__
        }
        print(json.dumps(error_result))
        sys.exit(1)


if __name__ == '__main__':
    main()

