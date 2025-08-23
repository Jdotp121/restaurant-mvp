export const dynamic = "force-dynamic";
"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";

export default function TestPage() {
  const [msg, setMsg] = useState("Loading...");

  useEffect(() => {
    (async () => {
      const { data, error } = await supabase.from("restaurants").select("*").limit(1);
      if (error) setMsg("Error: " + error.message);
      else setMsg(data?.length ? `OK: ${data[0].name}` : "OK: no restaurants found");
    })();
  }, []);

  return (
    <main className="p-8">
      <h1 className="text-2xl font-bold mb-2">Supabase Test</h1>
      <p>{msg}</p>
    </main>
  );
}
