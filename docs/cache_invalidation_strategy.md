# Contract Cache Invalidation Strategy

## Overview
This document describes the proactive cache invalidation strategy for the contracts index endpoint.

## Problem
The contracts index endpoint caches contract data including payment schedules. When payments are updated (e.g., marked as `reajustment` during capital repayment), the cache needs to be invalidated to show current data.

## Solution: Proactive Cache Invalidation

Instead of computing timestamps on every request to detect changes, we proactively invalidate the cache when modifications occur.

### Implementation

1. **Shared Concern**: `ContractCacheInvalidation`
   - Located in: `app/services/concerns/contract_cache_invalidation.rb`
   - Provides `invalidate_contracts_cache` method
   - Uses `Rails.cache.delete_matched('contracts/index/*')` to clear all cache entries

2. **Service Integration**:
   - Include the concern in services that modify contracts or payments
   - Call `invalidate_contracts_cache` after successful operations
   - Example: `CapitalRepaymentService`

3. **Controller**:
   - Simplified cache key (no need for timestamps)
   - Cache key: `contracts/index/{user_id}/{page}/{per_page}/{search}/{sort}`
   - TTL: 1 hour (as fallback)

### Services That Should Invalidate Cache

- ✅ `CapitalRepaymentService` - Marks payments as reajustment
- `CreateContractService` - Creates new contracts
- `CancelContractService` - Cancels contracts
- `PaymentCreationService` - Creates payments
- Payment approval/rejection actions

### Benefits

1. **Performance**: No expensive timestamp queries on every request
2. **Accuracy**: Cache is invalidated immediately when changes occur
3. **Simplicity**: Clean separation of concerns
4. **Maintainability**: Easy to add to new services

### Usage Example

```ruby
class Contracts::SomeService
  include ContractCacheInvalidation

  def call
    ActiveRecord::Base.transaction do
      # ... modify contract or payments ...
      invalidate_contracts_cache
    end
  end
end
```

### Testing

Cache invalidation should be tested in service specs:

```ruby
it 'invalidates the contracts cache' do
  expect(Rails.cache).to receive(:delete_matched).with('contracts/index/*')
  service.call
end
```
