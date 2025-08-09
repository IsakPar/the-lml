Error URN catalog (inventory holds):
- urn:lml:inventory:conflict -> 409; { type, title:"Seat(s) conflict", detail, instance, conflictSeatIds }
- urn:lml:inventory:not-found -> 404; { type, title:"Hold not found", detail, instance }
- urn:lml:inventory:expired -> 409 or 410; { type, title:"Hold expired", detail, instance }
- urn:lml:inventory:validation -> 422; { type, title:"Validation error", detail, instance, errors }
- urn:lml:platform:invalid-idempotency-key -> 422; { type, title:"Invalid Idempotency-Key", detail, instance }
All errors use RFC7807; types referenced in route specs.
