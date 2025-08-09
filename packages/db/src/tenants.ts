// Every DB operation during a request runs under SET LOCAL app.tenant_id = $tenantId. Missing tenant -> reject the request or fail DB op; all transactions must call withTenant(tenantId).
