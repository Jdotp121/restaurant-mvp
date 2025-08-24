import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase/server";
import { z } from "zod";

// Validate the incoming JSON body
const BodySchema = z.object({
  id: z.string(), // Supabase auth uid (string UUID)
  email: z.email(),
  role: z.enum(["customer", "staff"]).optional(),
});

export async function POST(req: NextRequest) {
  try {
    const json = await req.json();
    const parsed = BodySchema.safeParse(json);
    if (!parsed.success) {
      return NextResponse.json(
        { error: "Invalid body", details: z.treeifyError(parsed.error) },
        { status: 400 }
      );
    }

    const { id, email, role } = parsed.data;

    // If creating staff, associate to first restaurant for now
    let restaurantId: string | null = null;
    if (role === "staff") {
      const { data: r, error: rErr } = await supabaseAdmin
        .from("restaurants")
        .select("id")
        .limit(1)
        .maybeSingle();
      if (rErr) {
        return NextResponse.json({ error: rErr.message }, { status: 500 });
      }
      restaurantId = r?.id ?? null;
    }

    const { error } = await supabaseAdmin.from("users").upsert(
      {
        id,
        email,
        role: role ?? "customer",
        restaurant_id: restaurantId,
      },
      { onConflict: "id" }
    );

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ ok: true });
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : "Server error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
