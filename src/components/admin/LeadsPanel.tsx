import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

type Lead = {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  message?: string | null;
  created_at?: string | null;
  capital_range?: string | null;
  vehicles_interested?: number | null;
};

export function LeadsPanel({ table, label }: { table: "contact_leads" | "investor_leads"; label: string }) {
  const [rows, setRows] = useState<Lead[]>([]);

  useEffect(() => {
    supabase.from(table).select("*").order("created_at", { ascending: false })
      .then(({ data }) => setRows((data as Lead[]) || []));
  }, [table]);

  async function remove(id: string) {
    if (!confirm(`Delete this ${label.toLowerCase()}?`)) return;
    const { error } = await supabase.from(table).delete().eq("id", id);
    if (error) return toast.error(error.message);
    setRows((r) => r.filter((x) => x.id !== id));
    toast.success("Deleted");
  }

  return (
    <div className="space-y-2">
      {rows.map((c) => (
        <div key={c.id} className="rounded-xl bg-soft p-4">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0 flex-1">
              <div className="font-medium">{c.name}</div>
              <div className="text-xs text-muted-foreground">
                <a href={`mailto:${c.email}`} className="hover:underline">{c.email}</a>
                {c.phone && <> · <a href={`tel:${c.phone}`} className="hover:underline">{c.phone}</a></>}
                {c.capital_range && <> · {c.capital_range}</>}
                {c.vehicles_interested != null && <> · {c.vehicles_interested} vehicles</>}
              </div>
              {c.message && <p className="text-sm mt-2 whitespace-pre-wrap">{c.message}</p>}
              <div className="text-[11px] text-muted-foreground mt-2">{c.created_at && new Date(c.created_at).toLocaleString()}</div>
            </div>
            <button onClick={() => remove(c.id)} className="rounded-md border border-border px-3 py-1.5 text-sm hover:bg-real-red hover:text-white hover:border-real-red">Delete</button>
          </div>
        </div>
      ))}
      {rows.length === 0 && <div className="text-sm text-muted-foreground">No {label.toLowerCase()} yet.</div>}
    </div>
  );
}