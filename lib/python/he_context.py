#!/usr/bin/env python3
"""
HE Context Manager using TenSEAL

Manages TenSEAL context and key generation for homomorphic encryption
"""

import tenseal as ts
from typing import List, Tuple, Optional


class HeContext:
    """Manages TenSEAL context and key generation"""

    def __init__(self, poly_modulus_degree: int = 8192, coeff_mod_bit_sizes: List[int] = None):
        """
        Initialize HE context with BFV scheme

        Args:
            poly_modulus_degree: Security parameter (8192 = 128-bit security)
            coeff_mod_bit_sizes: Coefficient modulus chain
        """
        if coeff_mod_bit_sizes is None:
            coeff_mod_bit_sizes = [60, 40, 40, 60]

        # Create TenSEAL context with BFV scheme (for integer arithmetic)
        self.context = ts.context(
            ts.SCHEME_TYPE.BFV,
            poly_modulus_degree=poly_modulus_degree,
            plain_modulus=1032193  # Prime for BFV
        )

        # Generate Galois and relinearization keys for operations
        self.context.generate_galois_keys()
        self.context.generate_relin_keys()

    def get_public_context(self):
        """Get public context (without secret key) for encryption"""
        public_ctx = self.context.copy()
        public_ctx.make_context_public()
        return public_ctx

    def encrypt_vector(self, data: List[int]) -> ts.BFVVector:
        """Encrypt a vector of integers"""
        return ts.bfv_vector(self.context, data)

    def decrypt_vector(self, encrypted_vector) -> List[int]:
        """Decrypt a vector"""
        decrypted = encrypted_vector.decrypt()
        # Ensure we return a list of integers
        if isinstance(decrypted, list):
            return [int(x) for x in decrypted]
        return [int(decrypted)]

    def serialize_public_context(self) -> bytes:
        """Serialize public context for transmission"""
        public_ctx = self.get_public_context()
        return public_ctx.serialize()

    @staticmethod
    def deserialize_context(serialized: bytes):
        """Deserialize context"""
        return ts.context_from(serialized)

