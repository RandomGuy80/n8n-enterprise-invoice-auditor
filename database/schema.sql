-- 1. Two-Layer Idempotency Lock (Telegram file_unique_id + PDF SHA-256 content hash)
CREATE TABLE IF NOT EXISTS public.processed_events (
  event_key text PRIMARY KEY,
  source text NOT NULL,
  processed_at timestamptz DEFAULT now()
);

-- 2. Approved Vendor Price Catalog (Structured Tool RAG Source)
CREATE TABLE IF NOT EXISTS public.vendor_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sku text UNIQUE NOT NULL,
  item_name text NOT NULL,
  vendor_name text NOT NULL,
  approved_unit_price numeric(12, 2) NOT NULL,
  currency text NOT NULL DEFAULT 'RUB'
);

-- 3. B2B Invoices Registry & LLM Cost Observability Log
CREATE TABLE IF NOT EXISTS public.invoices_registry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number text NOT NULL,
  vendor_name text NOT NULL,
  total_amount numeric(12, 2) NOT NULL,
  currency text NOT NULL DEFAULT 'RUB',
  line_items jsonb NOT NULL,
  audit_status text NOT NULL, -- passed, price_mismatch, over_budget
  audit_notes text,
  approval_status text NOT NULL DEFAULT 'pending', -- auto_approved, pending, approved, rejected
  llm_tokens_used int DEFAULT 0,
  estimated_cost_usd numeric(10, 6) DEFAULT 0,
  approved_by text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 4. Dead-Letter Queue (DLQ for Failed Executions)
CREATE TABLE IF NOT EXISTS public.failed_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_name text NOT NULL,
  execution_id text,
  failed_node text,
  error_message text NOT NULL,
  payload jsonb,
  resolved boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Indexes & Role Permissions
CREATE INDEX IF NOT EXISTS idx_invoices_approval_status ON public.invoices_registry(approval_status);
CREATE INDEX IF NOT EXISTS idx_failed_jobs_resolved ON public.failed_jobs(resolved);

GRANT ALL PRIVILEGES ON TABLE 
  public.processed_events,
  public.vendor_catalog,
  public.invoices_registry,
  public.failed_jobs
TO anon, authenticated, service_role;

-- Sample Approved Vendor Catalog Data
INSERT INTO public.vendor_catalog (sku, item_name, vendor_name, approved_unit_price, currency)
VALUES
  ('SRV-01', 'Аренда выделенного сервера NVMe', 'ООО КлаудТех', 12000.00, 'RUB'),
  ('LIC-02', 'Лицензия CRM Enterprise (1 место)', 'ООО КлаудТех', 4500.00, 'RUB'),
  ('SUP-03', 'Техническая поддержка 24/7 (час)', 'ИП Смирнов А.В.', 3000.00, 'RUB')
ON CONFLICT (sku) DO NOTHING;
