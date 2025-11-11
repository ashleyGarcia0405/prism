# Backend Comparison Guide

## Overview
Prism supports four privacy-preserving query backends. Choose based on your use case, performance requirements, and privacy needs.

## Quick Comparison Table

| Backend | Status | Privacy Guarantee | Performance | Best For | Limitations |
|---------|--------|-------------------|-------------|----------|-------------|
| **Differential Privacy** | ✅ Functional | (ε, δ)-DP | Fast (~1s) | Single dataset, statistical queries | Adds noise to results |
| **Homomorphic Encryption** | ✅ Functional | IND-CPA | Slow (~10s) | Encrypted computation | Only SUM/COUNT, expensive |
| **Multi-Party Computation** | ⚠️ Mocked | Semi-honest security | Medium (~3s) | Multi-org queries | Requires coordination |
| **Secure Enclave** | ❌ Not Implemented | Hardware isolation | Medium (~2s) | Sensitive data | Requires SGX hardware |

## Detailed Comparison

### 1. Differential Privacy (dp_sandbox)

**Status**: ✅ Fully Functional

**Description**: Adds calibrated statistical noise to query results to protect individual records.

**Use Cases**:
- Census data analysis
- Healthcare research
- User analytics
- Public datasets with sensitive information

**Supported Operations**:
- COUNT, SUM, AVG, MIN, MAX
- GROUP BY with HAVING
- Simple WHERE clauses

**Privacy Guarantee**: (ε, δ)-differential privacy
- ε (epsilon): 0.1 - 3.0 (configurable)
- δ (delta): 10^-5 (default)
- Mathematical guarantee that individual records cannot be distinguished

**Performance**:
- Execution time: 100ms - 1s
- Scales linearly with data size
- Minimal computational overhead

**Pros**:
- ✅ Fast execution
- ✅ Well-understood privacy guarantees
- ✅ Works on any data
- ✅ Supports complex queries
- ✅ Active research and development

**Cons**:
- ❌ Adds noise to results (approximate)
- ❌ Consumes privacy budget (limited queries)
- ❌ Cannot guarantee exact results
- ❌ Requires understanding of privacy parameters

---

### 2. Homomorphic Encryption (he_backend)

**Status**: ✅ Functional (SUM, COUNT only)

**Description**: Performs computations directly on encrypted data without decryption using TenSEAL (Microsoft SEAL).

**Use Cases**:
- Financial data aggregation
- Encrypted cloud analytics
- Privacy-preserving machine learning
- Scenarios where server must never see plaintext

**Supported Operations**:
- COUNT, SUM
- Weighted operations
- **NOT Supported**: AVG (requires division), MIN/MAX (requires comparison)

**Privacy Guarantee**: IND-CPA secure encryption
- Based on lattice cryptography (BFV scheme)
- Post-quantum secure
- 128-bit security level
- Server cannot decrypt data during computation

**Performance**:
- Encryption: ~500ms per 1000 records
- Computation: ~5-20s per operation
- Decryption: ~50ms
- Total: ~2-30s depending on data size

**Technical Details**:
- Encryption Scheme: BFV (Brakerski-Fan-Vercauteren)
- Polynomial Modulus Degree: 8192
- Key Management: Generated per query, not persisted

**Pros**:
- ✅ Server never sees plaintext data
- ✅ Exact results (no noise)
- ✅ Post-quantum secure
- ✅ Cryptographic security guarantees

**Cons**:
- ❌ Very slow (10-100x slower than DP)
- ❌ Limited operations (only SUM/COUNT)
- ❌ Large ciphertext sizes
- ❌ Complex implementation and debugging

---

### 3. Multi-Party Computation (mpc_backend)

**Status**: ⚠️ Mocked (Simulated)

**Description**: Multiple organizations jointly compute without revealing their data using secret sharing protocols.

**Use Cases**:
- Cross-hospital research
- Multi-bank fraud detection
- Supply chain analytics
- Collaborative research across competitors

**Supported Operations** (when fully implemented):
- COUNT, SUM, AVG
- Simple aggregations across parties
- Basic statistical queries

**Privacy Guarantee**: Semi-honest security
- Additive secret sharing (Shamir's Secret Sharing)
- No single party sees others' data
- Requires non-colluding parties
- Threshold security (t-of-n)

**Performance** (estimated for real implementation):
- Setup: ~1s per party
- Computation: ~2-5s total
- Communication: ~100KB per party
- Network-dependent latency

**Current Implementation**: 
- ⚠️ **Mocked** - Returns simulated results for demonstration
- Real MPC implementation requires coordination infrastructure
- See MPC_IMPLEMENTATION_PLAN.md for details

**Pros**:
- ✅ Enables multi-org queries
- ✅ No centralized data storage
- ✅ Exact results (no noise)
- ✅ Cryptographic security

**Cons**:
- ❌ Currently only mocked
- ❌ Requires coordination between parties
- ❌ Network dependent
- ❌ Complex setup and orchestration

---

### 4. Secure Enclave (enclave_backend)

**Status**: ❌ Not Implemented

**Description**: Hardware-based trusted execution environment using Intel SGX, AMD SEV, or ARM TrustZone.

**Use Cases**:
- Highly sensitive data (medical, financial)
- Compliance requirements (GDPR, HIPAA)
- Untrusted cloud environments
- Scenarios requiring hardware attestation

**Supported Operations** (when implemented):
- All SQL operations
- Full query language support
- Complex joins and aggregations

**Privacy Guarantee**: Hardware-backed isolation
- Encrypted memory (CPU-level encryption)
- Remote attestation (proof of correct execution)
- Side-channel protections
- Isolated execution environment

**Performance** (estimated):
- Initialization: ~500ms
- Query execution: ~1-3s
- Attestation: ~200ms
- Near-native performance

**Implementation Requirements**:
- Intel CPU with SGX support (Ice Lake or newer)
- Gramine or Occlum runtime
- Remote attestation service
- 4-6 weeks development effort

**Pros**:
- ✅ Full SQL support
- ✅ Hardware-backed security
- ✅ Reasonable performance
- ✅ Industry-standard technology

**Cons**:
- ❌ Requires specific hardware
- ❌ Complex implementation
- ❌ Potential side-channel vulnerabilities
- ❌ Limited cloud provider support

---

## Decision Matrix

### Choose Differential Privacy if:
- ✅ You have a single dataset
- ✅ You need fast queries
- ✅ Approximate results are acceptable
- ✅ You understand privacy budgets
- ✅ You need support for complex queries

### Choose Homomorphic Encryption if:
- ✅ You need exact results
- ✅ Server must never see plaintext
- ✅ Only COUNT/SUM operations needed
- ✅ You can tolerate slow execution
- ✅ Post-quantum security is important

### Choose MPC if:
- ✅ Multiple organizations involved
- ✅ No party should see others' data
- ✅ You can coordinate execution
- ⚠️ **CURRENTLY MOCKED** - for testing only
- ⚠️ Wait for full implementation

### Choose Secure Enclave if:
- ❌ **NOT YET AVAILABLE**
- ❌ Use alternative backends
- 🔮 Check back in future releases

---

## Example Queries by Backend

### Differential Privacy
```sql
-- ✅ Works great
SELECT state, AVG(age), COUNT(*)
FROM patients
GROUP BY state
HAVING COUNT(*) >= 25

-- Result: Approximate (noisy) but fast
-- Example: state='CA', avg=45.3±2.1, count=1023±15
```

### Homomorphic Encryption
```sql
-- ✅ Supported
SELECT SUM(salary) FROM employees
-- Result: Exact sum on encrypted data

-- ❌ NOT Supported (yet)
SELECT AVG(salary) FROM employees
-- Error: AVG requires division, not supported in HE
```

### Multi-Party Computation
```sql
-- ⚠️ Will work when implemented (currently mocked)
SELECT COUNT(*) FROM combined_datasets
WHERE diagnosis = 'diabetes'

-- Currently returns: simulated results for demonstration
```

---

## Performance Benchmarks

Based on 1000 records:

| Backend | COUNT | SUM | AVG | GROUP BY |
|---------|-------|-----|-----|----------|
| DP | 120ms | 150ms | 180ms | 300ms |
| HE | 8s | 12s | N/A | N/A |
| MPC | ~3s (mocked) | ~4s (mocked) | ~4s (mocked) | N/A |
| Enclave | N/A | N/A | N/A | N/A |

**Note**: Benchmarks are approximate and depend on:
- Hardware specifications
- Data size and complexity
- Query complexity
- Network latency (for MPC)

---

## Security Guarantees Summary

| Backend | Protects Against | Assumes | Threat Model |
|---------|------------------|---------|--------------|
| DP | Record linkage, inference attacks | Trusted server | Honest-but-curious adversary |
| HE | Curious server, data breaches | Trusted key management | Malicious server |
| MPC | Curious parties | Semi-honest behavior | Honest majority |
| Enclave | Curious admin, OS compromise | Trusted hardware | Malicious software |

---

## Privacy Budget Consumption

| Backend | Consumes ε Budget | Requires δ | Limits |
|---------|------------------|-----------|--------|
| DP | ✅ Yes | ✅ Yes | Total budget: 3.0 ε |
| HE | ❌ No | ❌ No | No limits |
| MPC | ❌ No | ❌ No | Coordination limits |
| Enclave | ❌ No | ❌ No | No limits |

---

## Getting Started

### Quick Start Guide

1. **Try Differential Privacy first** - it's fast, functional, and well-documented
   ```ruby
   query = dataset.queries.create!(
     sql: "SELECT COUNT(*) FROM patients",
     backend: 'dp_sandbox'
   )
   ```

2. **Use HE for exact SUM/COUNT** if you need precise results
   ```ruby
   query = dataset.queries.create!(
     sql: "SELECT SUM(salary) FROM employees",
     backend: 'he_backend'
   )
   ```

3. **Test MPC** for multi-org workflows (returns mocked results)
   ```ruby
   query = dataset.queries.create!(
     sql: "SELECT COUNT(*) FROM combined",
     backend: 'mpc_backend'
   )
   ```

4. **Avoid Enclave** for now (returns informative error with alternatives)

---

## API Usage

### Creating a Query with Backend Selection

```ruby
POST /api/v1/queries
{
  "query": {
    "dataset_id": 123,
    "sql": "SELECT COUNT(*) FROM patients",
    "backend": "dp_sandbox"  // Options: dp_sandbox, he_backend, mpc_backend, enclave_backend
  }
}
```

### Validating Query for Backend

```ruby
POST /api/v1/queries/validate
{
  "sql": "SELECT SUM(age) FROM patients",
  "backend": "he_backend"
}

Response:
{
  "valid": true,
  "backend": {
    "name": "he_backend",
    "supported": true,
    "features": ["COUNT", "SUM"]
  }
}
```

---

## Further Reading

- **Differential Privacy**: See `docs/DP_IMPLEMENTATION.md`
- **Homomorphic Encryption**: See `docs/HE_IMPLEMENTATION.md`
- **Multi-Party Computation**: See `docs/MPC_IMPLEMENTATION_PLAN.md`
- **Secure Enclaves**: Implementation guide included in error message

---

## Frequently Asked Questions

**Q: Why use DP if results are noisy?**
A: For statistical analysis where approximate results are acceptable and speed matters. The privacy budget provides a mathematical guarantee of privacy.

**Q: Why is HE so slow?**
A: Homomorphic operations on encrypted data are computationally expensive. Each operation requires polynomial multiplications in the ciphertext space.

**Q: When will MPC be fully implemented?**
A: MPC implementation is planned for a future release. The current mock allows testing workflows. See `MPC_IMPLEMENTATION_PLAN.md` for timeline.

**Q: Why no Enclave backend?**
A: Requires SGX hardware and complex integration. Currently low priority since other backends provide strong privacy guarantees. See error message for implementation details.

**Q: Which backend is most secure?**
A: It depends on your threat model:
- **DP**: Best for statistical guarantees against inference
- **HE**: Best for protecting against server compromise
- **MPC**: Best for multi-party scenarios
- **Enclave**: Best for hardware-backed guarantees (when implemented)

**Q: Can I use multiple backends for the same dataset?**
A: Yes! Each query can specify its own backend. Different queries on the same dataset can use different backends based on requirements.

---

## Support and Contact

For questions or issues with backends:
- Check error messages (especially for Enclave - they include detailed guidance)
- Review backend-specific documentation
- Examine test files for usage examples
- Contact the development team

---

**Last Updated**: November 2025
**Version**: 1.0

