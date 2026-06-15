import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { Plus, X, Globe } from "lucide-react";

type Site = {
  id: string;
  slug: string;
  title: string;
  market_id: string | null;
  is_published: boolean;
};

export function WebsitesPanel() {
  const [sites, setSites] = useState<Site[]>([]);
  const [markets, setMarkets] = useState<{ id: string; name: string }[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);

  async function load() {
    setLoading(true);
    const [s, m] = await Promise.all([
      supabase.from("sites").select("*").order("title"),
      supabase.from("markets").select("id, name").order("name"),
    ]);
    if (s.error) toast.error(s.error.message);
    setSites((s.data as any) ?? []);
    setMarkets((m.data as any) ?? []);
    setLoading(false);
  }
  useEffect(() => { load(); }, []);

  async function togglePublish(id: string, is_published: boolean) {
    const { error } = await supabase.from("sites").update({ is_published: !is_published }).eq("id", id);
    if (error) return toast.error(error.message);
    load();
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <span className="text-sm text-muted-foreground">{sites.length} site(s)</span>
        <button onClick={() => setShowForm(true)} className="inline-flex items-center gap-2 rounded-lg bg-real-red text-white px-4 py-2 text-sm font-medium">
          <Plus className="w-4 h-4" /> New Site
        </button>
      </div>
      {loading ? <p className="text-sm text-muted-foreground">Loading…</p> : sites.length === 0 ? (
        <div className="rounded-xl border border-border p-10 text-center text-muted-foreground">
          <Globe className="w-8 h-8 mx-auto mb-2 opacity-50" />
          <p className="text-sm">No market sites yet.</p>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border">
          <table className="w-full text-sm">
            <thead className="bg-soft text-xs uppercase tracking-wider text-muted-foreground text-left">
              <tr><th className="px-4 py-2">Title</th><th>Slug</th><th>Market</th><th>Status</th><th></th></tr>
            </thead>
            <tbody className="divide-y divide-border">
              {sites.map((s) => (
                <tr key={s.id}>
                  <td className="px-4 py-2 font-medium">{s.title}</td>
                  <td><code className="text-xs">/{s.slug}</code></td>
                  <td className="text-muted-foreground">{markets.find((m) => m.id === s.market_id)?.name ?? "—"}</td>
                  <td>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${s.is_published ? "bg-green-100 text-green-700" : "bg-soft text-muted-foreground"}`}>
                      {s.is_published ? "Published" : "Draft"}
                    </span>
                  </td>
                  <td className="px-4 py-2 text-right">
                    <button onClick={() => togglePublish(s.id, s.is_published)} className="text-xs rounded border border-border px-2 py-1">
                      {s.is_published ? "Unpublish" : "Publish"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {showForm && <NewSiteForm markets={markets} onClose={() => setShowForm(false)} onCreated={() => { setShowForm(false); load(); }} />}
    </div>
  );
}

function NewSiteForm({ markets, onClose, onCreated }: { markets: { id: string; name: string }[]; onClose: () => void; onCreated: () => void }) {
  const [title, setTitle] = useState("");
  const [slug, setSlug] = useState("");
  const [marketId, setMarketId] = useState<string>(markets[0]?.id ?? "");
  const [saving, setSaving] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!title || !slug) return toast.error("Title and slug required");
    setSaving(true);
    const { error } = await supabase.from("sites").insert({ title, slug, market_id: marketId || null } as any);
    setSaving(false);
    if (error) return toast.error(error.message);
    toast.success("Created");
    onCreated();
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <form onSubmit={submit} className="bg-white rounded-xl p-6 max-w-md w-full space-y-3">
        <div className="flex items-center justify-between"><h3 className="font-semibold">New Site</h3><button type="button" onClick={onClose}><X className="w-4 h-4" /></button></div>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" className="w-full rounded border border-border px-3 py-2 text-sm" />
        <input value={slug} onChange={(e) => setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, "-"))} placeholder="slug" className="w-full rounded border border-border px-3 py-2 text-sm" />
        <select value={marketId} onChange={(e) => setMarketId(e.target.value)} className="w-full rounded border border-border bg-white px-3 py-2 text-sm">
          <option value="">No market</option>
          {markets.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
        </select>
        <button disabled={saving} className="w-full rounded-lg bg-real-red text-white py-2 text-sm font-medium">{saving ? "Saving…" : "Create"}</button>
      </form>
    </div>
  );
}