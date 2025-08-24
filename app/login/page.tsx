"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm, SubmitHandler } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { supabase } from "@/lib/supabase/client";

// Make mode and role required in the schema:
const schema = z.object({
  email: z.string().email("Invalid email address"), // updated to recommended API
  password: z.string().min(6, "Min 6 characters"),
  mode: z.enum(["signup", "signin"]),
  role: z.enum(["customer", "staff"]),
});

// Use z.infer since there are no .default(...) values:
type AuthForm = z.infer<typeof schema>;

export default function LoginPage() {
  const [msg, setMsg] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<AuthForm>({
    resolver: zodResolver(schema),
    // provide concrete defaults so RHF knows initial values
    defaultValues: { email: "", password: "", mode: "signup", role: "customer" },
  });

  const onSubmit: SubmitHandler<AuthForm> = async (values) => {
    setMsg(null);

    if (values.mode === "signup") {
      const { error } = await supabase.auth.signUp({
        email: values.email,
        password: values.password,
      });
      if (error) { setMsg(error.message); return; }
    } else {
      const { error } = await supabase.auth.signInWithPassword({
        email: values.email,
        password: values.password,
      });
      if (error) { setMsg(error.message); return; }
    }

    // ensure a users row exists
    const { data: sessionData } = await supabase.auth.getSession();
    const user = sessionData.session?.user;
    const accessToken = sessionData.session?.access_token;

    if (!user || !accessToken) { setMsg("Logged in, but no session found."); return; }

    const res = await fetch("/api/ensure-user", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ id: user.id, email: user.email, role: values.role }),
    });

    if (!res.ok) { setMsg("Ensure user failed: " + (await res.text())); return; }

    window.location.href = "/";
  };

  return (
    <main className="max-w-md mx-auto p-6 space-y-4">
      <h1 className="text-2xl font-bold">Login / Sign up</h1>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
        <label className="block">
          <span className="text-sm">Email</span>
          <input className="w-full border rounded p-2 bg-black/10" type="email" {...register("email")} />
          {errors.email && <p className="text-red-500 text-sm">{errors.email.message}</p>}
        </label>

        <label className="block">
          <span className="text-sm">Password</span>
          <input className="w-full border rounded p-2 bg-black/10" type="password" {...register("password")} />
          {errors.password && <p className="text-red-500 text-sm">{errors.password.message}</p>}
        </label>

        <div className="flex gap-6">
          <label className="flex items-center gap-2">
            <input type="radio" value="signup" {...register("mode")} />
            <span>Sign up</span>
          </label>
          <label className="flex items-center gap-2">
            <input type="radio" value="signin" {...register("mode")} />
            <span>Sign in</span>
          </label>
        </div>

        <div className="flex gap-6">
          <label className="flex items-center gap-2">
            <input type="radio" value="customer" {...register("role")} />
            <span>Customer</span>
          </label>
          <label className="flex items-center gap-2">
            <input type="radio" value="staff" {...register("role")} />
            <span>Staff</span>
          </label>
        </div>

        <button disabled={isSubmitting} className="px-4 py-2 rounded bg-white text-black disabled:opacity-60">
          {isSubmitting ? "Working..." : "Continue"}
        </button>
      </form>

      {msg && <p className="text-yellow-400">{msg}</p>}

      <p className="text-sm text-gray-400">
        Back to <Link href="/" className="underline">home</Link>
      </p>
    </main>
  );
}
