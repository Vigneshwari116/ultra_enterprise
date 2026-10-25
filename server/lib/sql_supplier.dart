/// Supplier name lives in envelope `data` JSON on the live VPS schema.
const supplierPartyNameExpr = "COALESCE(s.data::jsonb->>'supplier_name', '-')";

const supplierJoin = 'LEFT JOIN suppliers s ON s.id = po.supplier_id';
