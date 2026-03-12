# setup.ps1 - Ejecutar desde la carpeta tesoreria-curso
# PowerShell: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Write-Host 'Creando carpetas...' -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path 'src' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\actions' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\app' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\app\apoderado' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\app\change-password' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\app\dashboard' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\app\login' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\components' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\lib' | Out-Null
New-Item -ItemType Directory -Force -Path 'src\lib\supabase' | Out-Null

Write-Host 'Creando src\lib\supabase\types.ts...'
@'
// src/lib/supabase/types.ts

export type QuotaType = 'mensual' | 'especial'
export type UserRole  = 'tesorera' | 'apoderado'

export interface School {
  id: string
  name: string
  created_at: string
}

export interface Course {
  id: string
  school_id: string
  name: string
  period: string
  created_at: string
}

export interface AppUser {
  id: string
  auth_id: string
  course_id: string
  username: string
  display_name: string
  role: UserRole
  must_change_password: boolean
  created_at: string
}

export interface Student {
  id: string
  course_id: string
  name: string
  created_at: string
}

export interface ApoderadoStudent {
  apoderado_id: string
  student_id: string
}

export interface Quota {
  id: string
  course_id: string
  name: string
  type: QuotaType
  amount: number
  due_date: string | null
  participant_ids: string[] | null  // null = todo el curso
  created_at: string
}

export interface Payment {
  id: string
  course_id: string
  student_id: string
  quota_id: string
  paid_at: string
  created_by: string | null
  created_at: string
}

export interface Expense {
  id: string
  course_id: string
  description: string
  amount: number
  category: string
  date: string
  created_by: string | null
  created_at: string
}

// ── Tipos compuestos para la UI ───────────────────────────────

export interface AppUserWithStudents extends AppUser {
  students: Student[]
}

export interface QuotaProjection extends Quota {
  participants: string[]   // IDs de alumnos que deben pagar
  expected: number         // monto total esperado
  paid: number             // monto recaudado
  pct: number              // porcentaje
  missing: number          // monto faltante
}

export interface StudentPaymentStatus {
  student: Student
  quotas: {
    quota: Quota
    applies: boolean
    paid: boolean
    payment?: Payment
  }[]
  totalPaid: number
  totalExpected: number
}

// ── Supabase Database types (para el cliente tipado) ─────────
export type Database = {
  public: {
    Tables: {
      schools:             { Row: School;           Insert: Omit<School,'id'|'created_at'>;           Update: Partial<School> }
      courses:             { Row: Course;           Insert: Omit<Course,'id'|'created_at'>;           Update: Partial<Course> }
      app_users:           { Row: AppUser;          Insert: Omit<AppUser,'id'|'created_at'>;          Update: Partial<AppUser> }
      students:            { Row: Student;          Insert: Omit<Student,'id'|'created_at'>;          Update: Partial<Student> }
      apoderado_students:  { Row: ApoderadoStudent; Insert: ApoderadoStudent;                         Update: Partial<ApoderadoStudent> }
      quotas:              { Row: Quota;            Insert: Omit<Quota,'id'|'created_at'>;            Update: Partial<Quota> }
      payments:            { Row: Payment;          Insert: Omit<Payment,'id'|'created_at'>;          Update: Partial<Payment> }
      expenses:            { Row: Expense;          Insert: Omit<Expense,'id'|'created_at'>;          Update: Partial<Expense> }
    }
  }
}

'@ | Out-File -FilePath 'src\lib\supabase\types.ts' -Encoding utf8

Write-Host 'Creando src\lib\supabase\client.ts...'
@'
// src/lib/supabase/client.ts
// Usar en componentes cliente ('use client')

import { createBrowserClient } from '` @supabase/ssr'
import type { Database } from './types'

export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}

'@ | Out-File -FilePath 'src\lib\supabase\client.ts' -Encoding utf8

Write-Host 'Creando src\lib\supabase\server.ts...'
@'
// src/lib/supabase/server.ts
// Usar en Server Components y Server Actions

import { createServerClient } from '` @supabase/ssr'
import { cookies } from 'next/headers'
import type { Database } from './types'

export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return cookieStore.getAll() },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {}
        },
      },
    }
  )
}

// Cliente con service role — SOLO para Server Actions sensibles
// (crear usuarios en auth, etc.)
export function createServiceClient() {
  const { createClient } = require('` @supabase/supabase-js')
  return createClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )
}

'@ | Out-File -FilePath 'src\lib\supabase\server.ts' -Encoding utf8

Write-Host 'Creando src\middleware.ts...'
@'
// src/middleware.ts
// Protege las rutas — redirige si no hay sesión activa

import { createServerClient } from '` @supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()

  const path = request.nextUrl.pathname

  // Rutas públicas
  const publicPaths = ['/login', '/change-password']
  const isPublic = publicPaths.some(p => path.startsWith(p))

  // Sin sesión → redirigir a login
  if (!user && !isPublic) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Con sesión en login → redirigir a home
  if (user && path === '/login') {
    return NextResponse.redirect(new URL('/dashboard', request.url))
  }

  return supabaseResponse
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api).*)'],
}

'@ | Out-File -FilePath 'src\middleware.ts' -Encoding utf8

Write-Host 'Creando src\app\layout.tsx...'
@'
// src/app/layout.tsx
import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Tesorería Curso',
  description: 'Gestión de tesorería para cursos escolares',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <head>
        <link
          href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,300;0,9..144,700;0,9..144,900;1,9..144,400&family=Instrument+Sans:wght@400;500;600;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  )
}

'@ | Out-File -FilePath 'src\app\layout.tsx' -Encoding utf8

Write-Host 'Creando src\app\globals.css...'
@'
/* src/app/globals.css */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --ink:        #0d0d12;
  --slate:      #3d3d52;
  --muted:      #8886a0;
  --border:     #e8e7f0;
  --bg:         #f5f4fa;
  --white:      #ffffff;
  --indigo:     #5b4df5;
  --indigo-lt:  #ede9ff;
  --green:      #059669;
  --green-lt:   #d1fae5;
  --red:        #dc2626;
  --red-lt:     #fee2e2;
  --amber:      #d97706;
  --amber-lt:   #fef3c7;
  --blue:       #0369a1;
  --blue-lt:    #e0f2fe;
  --gray-lt:    #f3f3f7;
  --shadow:     0 2px 12px rgba(91,77,245,0.08);
}

body {
  font-family: 'Instrument Sans', sans-serif;
  background: var(--bg);
  color: var(--ink);
}

/* ── TOPBAR ───────────────────────────────────────────────────── */
.topbar { background:var(--ink); color:#fff; padding:0 28px; height:54px; display:flex; align-items:center; justify-content:space-between; position:sticky; top:0; z-index:100; }
.topbar-title { font-family:'Fraunces',serif; font-size:17px; font-weight:900; letter-spacing:-0.03em; }
.topbar-title span { color:#a5b4fc; }
.topbar-sub { font-size:10px; color:#6b7280; margin-top:1px; }
.topbar-nav { display:flex; gap:2px; }
.topbar-right { display:flex; align-items:center; gap:10px; }
.topbar-user { font-size:11px; color:#9ca3af; }

/* ── NAV ─────────────────────────────────────────────────────── */
.nav-btn { padding:6px 13px; border-radius:7px; border:none; cursor:pointer; font-family:'Instrument Sans',sans-serif; font-size:12px; font-weight:600; transition:all 0.15s; }
.nav-btn.active   { background:rgba(255,255,255,0.12); color:#fff; }
.nav-btn.inactive { background:transparent; color:#9ca3af; }
.nav-btn.inactive:hover { color:#fff; background:rgba(255,255,255,0.06); }

/* ── CONTENT ─────────────────────────────────────────────────── */
.content { max-width:1100px; margin:0 auto; padding:24px 22px; }

/* ── CARDS ───────────────────────────────────────────────────── */
.card { background:var(--white); border-radius:13px; padding:20px 22px; box-shadow:var(--shadow); border:1px solid var(--border); }
.card-title { font-family:'Fraunces',serif; font-size:16px; font-weight:700; color:var(--ink); margin-bottom:16px; letter-spacing:-0.02em; }
.card-grid   { display:grid; gap:14px; }
.card-grid-3 { grid-template-columns:repeat(3,1fr); }
.card-grid-2 { grid-template-columns:repeat(2,1fr); }

/* ── KPI ─────────────────────────────────────────────────────── */
.kpi { border-radius:11px; padding:16px 18px; }
.kpi-label { font-size:10px; font-weight:700; letter-spacing:0.07em; text-transform:uppercase; margin-bottom:5px; }
.kpi-value { font-family:'Fraunces',serif; font-size:24px; font-weight:900; letter-spacing:-0.03em; }
.kpi-sub   { font-size:11px; margin-top:3px; opacity:0.7; }
.kpi-indigo { background:var(--indigo-lt); color:var(--indigo); }
.kpi-green  { background:var(--green-lt);  color:var(--green);  }
.kpi-red    { background:var(--red-lt);    color:var(--red);    }
.kpi-amber  { background:var(--amber-lt);  color:var(--amber);  }

/* ── TABLA ───────────────────────────────────────────────────── */
.tbl { width:100%; border-collapse:collapse; }
.tbl th { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:0.06em; color:var(--muted); padding:8px 11px; text-align:left; border-bottom:1.5px solid var(--border); }
.tbl td { padding:10px 11px; font-size:13px; border-bottom:1px solid #f3f3f8; }
.tbl tr:last-child td { border-bottom:none; }
.tbl tr:hover td { background:#fafaff; }

/* ── BADGES ──────────────────────────────────────────────────── */
.badge { display:inline-flex; align-items:center; gap:3px; border-radius:99px; font-size:10px; font-weight:700; padding:3px 9px; white-space:nowrap; }
.badge-green  { background:var(--green-lt);  color:#065f46; }
.badge-red    { background:var(--red-lt);    color:#991b1b; }
.badge-amber  { background:var(--amber-lt);  color:#78350f; }
.badge-indigo { background:var(--indigo-lt); color:#4338ca; }
.badge-blue   { background:var(--blue-lt);   color:#075985; }
.badge-gray   { background:var(--gray-lt);   color:var(--muted); }

/* ── BOTONES ─────────────────────────────────────────────────── */
.btn { border:none; border-radius:8px; cursor:pointer; font-family:'Instrument Sans',sans-serif; font-weight:700; transition:all 0.15s; display:inline-flex; align-items:center; gap:5px; }
.btn-primary { background:var(--indigo); color:#fff; padding:8px 16px; font-size:12px; }
.btn-primary:hover { background:#4a3de0; }
.btn-danger  { background:var(--red);    color:#fff; padding:8px 16px; font-size:12px; }
.btn-ghost   { background:var(--border); color:var(--slate); padding:8px 16px; font-size:12px; }
.btn-green   { background:var(--green);  color:#fff; padding:8px 16px; font-size:12px; }
.btn-green:hover { background:#047857; }
.btn-sm      { padding:4px 11px !important; font-size:11px !important; }
.btn-red-sm  { background:var(--red-lt); color:#991b1b; padding:4px 11px; font-size:11px; border:none; border-radius:8px; cursor:pointer; font-weight:700; }
.btn:disabled { opacity:0.4; cursor:default; }

/* ── FORM ────────────────────────────────────────────────────── */
.form-label { display:block; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:0.07em; color:var(--muted); margin-bottom:5px; }
.form-input { width:100%; padding:9px 11px; border:1.5px solid var(--border); border-radius:8px; font-family:'Instrument Sans',sans-serif; font-size:13px; color:var(--ink); outline:none; transition:border 0.15s; margin-bottom:12px; background:#fff; }
.form-input:focus { border-color:var(--indigo); }

/* ── MODAL ───────────────────────────────────────────────────── */
.overlay { position:fixed; inset:0; background:rgba(13,13,18,0.65); z-index:200; display:flex; align-items:center; justify-content:center; backdrop-filter:blur(2px); }
.modal { background:var(--white); border-radius:16px; padding:26px 30px; width:480px; box-shadow:0 32px 80px rgba(0,0,0,0.25); max-height:90vh; overflow-y:auto; }
.modal-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; }
.modal-title  { font-family:'Fraunces',serif; font-size:18px; font-weight:700; color:var(--ink); letter-spacing:-0.02em; }
.modal-close  { background:none; border:none; cursor:pointer; color:var(--muted); font-size:18px; padding:2px 6px; border-radius:6px; }
.modal-close:hover { background:var(--border); }
.modal-footer { display:flex; gap:8px; margin-top:4px; }
.modal-footer .btn { flex:1; justify-content:center; }

/* ── ALERT ───────────────────────────────────────────────────── */
.alert { border-radius:8px; padding:10px 13px; font-size:12px; font-weight:600; margin-bottom:12px; }
.alert-amber { background:var(--amber-lt); color:#78350f; }
.alert-green  { background:var(--green-lt); color:#065f46; }
.alert-red    { background:var(--red-lt);   color:#991b1b; }
.alert-blue   { background:var(--blue-lt);  color:#075985; }

/* ── PROGRESS ────────────────────────────────────────────────── */
.progress-bar  { height:8px; background:var(--border); border-radius:99px; overflow:hidden; margin-top:5px; }
.progress-fill { height:100%; border-radius:99px; transition:width 0.5s; }

/* ── UTILS ───────────────────────────────────────────────────── */
.row     { display:flex; align-items:center; justify-content:space-between; }
.divider { height:1px; background:var(--border); margin:16px 0; }
.mb-4    { margin-bottom:16px; }
.mb-3    { margin-bottom:12px; }
.mt-3    { margin-top:12px; }
.fw-700  { font-weight:700; }
.fs-12   { font-size:12px; }
.fs-13   { font-size:13px; }
.c-muted   { color:var(--muted); }
.c-green   { color:var(--green); }
.c-red     { color:var(--red); }
.c-indigo  { color:var(--indigo); }

/* ── CHECKBOXES ──────────────────────────────────────────────── */
.check-grid { display:grid; grid-template-columns:1fr 1fr; gap:7px; margin-bottom:12px; }
.check-item { display:flex; align-items:center; gap:7px; padding:8px 10px; border:1.5px solid var(--border); border-radius:8px; cursor:pointer; font-size:12px; transition:all 0.12s; }
.check-item.checked { border-color:var(--indigo); background:var(--indigo-lt); color:var(--indigo); font-weight:600; }
.check-item input { accent-color:var(--indigo); width:13px; height:13px; }
.check-all  { display:flex; gap:7px; margin-bottom:7px; }
.check-tag  { font-size:11px; font-weight:700; padding:3px 9px; border-radius:99px; border:none; cursor:pointer; background:var(--gray-lt); color:var(--muted); }
.check-tag:hover { background:var(--indigo-lt); color:var(--indigo); }

/* ── PRINT ───────────────────────────────────────────────────── */
@media print {
  .no-print { display:none !important; }
}

'@ | Out-File -FilePath 'src\app\globals.css' -Encoding utf8

Write-Host 'Creando src\app\login\page.tsx...'
@'
// src/app/login/page.tsx
'use client'

import { useState, useTransition } from 'react'
import { loginAction } from '` @/actions/auth'

export default function LoginPage() {
  const [error, setError]       = useState('')
  const [isPending, startTransition] = useTransition()
  const [form, setForm]         = useState({ username: '', password: '' })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    const fd = new FormData()
    fd.append('username', form.username)
    fd.append('password', form.password)

    startTransition(async () => {
      const result = await loginAction(fd)
      if (result?.error) setError(result.error)
    })
  }

  return (
    <div style={{
      minHeight: '100vh',
      background: '#0d0d12',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: "'Instrument Sans', sans-serif",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,900;1,9..144,400&family=Instrument+Sans:wght@400;600;700&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        input::placeholder { color: #6b7280; }
        input:focus { border-color: #a5b4fc !important; outline: none; }
      `}</style>

      <div style={{
        background: 'rgba(255,255,255,0.04)',
        border: '1.5px solid rgba(255,255,255,0.1)',
        borderRadius: 20,
        padding: '40px 44px',
        width: 380,
      }}>
        <div style={{ fontFamily: "'Fraunces', serif", fontSize: 28, fontWeight: 900, color: '#fff', letterSpacing: '-0.04em', marginBottom: 4 }}>
          Tesorería <em style={{ color: '#a5b4fc' }}>Curso</em>
        </div>
        <div style={{ color: '#6b7280', fontSize: 13, marginBottom: 32 }}>
          Ingresa con tu usuario y contraseña
        </div>

        {error && (
          <div style={{ background: 'rgba(220,38,38,0.15)', border: '1px solid rgba(220,38,38,0.3)', borderRadius: 8, padding: '10px 12px', color: '#fca5a5', fontSize: 12, fontWeight: 600, marginBottom: 16 }}>
            ⚠️ {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <label style={{ display: 'block', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.07em', color: '#9ca3af', marginBottom: 5 }}>
            Usuario
          </label>
          <input
            style={{ width: '100%', padding: '11px 14px', border: '1.5px solid rgba(255,255,255,0.1)', borderRadius: 9, fontSize: 14, background: 'rgba(255,255,255,0.06)', color: '#fff', marginBottom: 14, transition: 'border 0.15s' }}
            value={form.username}
            onChange={e => setForm(f => ({ ...f, username: e.target.value }))}
            placeholder="ej: tesorera"
            autoComplete="username"
          />

          <label style={{ display: 'block', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.07em', color: '#9ca3af', marginBottom: 5 }}>
            Contraseña
          </label>
          <input
            type="password"
            style={{ width: '100%', padding: '11px 14px', border: '1.5px solid rgba(255,255,255,0.1)', borderRadius: 9, fontSize: 14, background: 'rgba(255,255,255,0.06)', color: '#fff', marginBottom: 24, transition: 'border 0.15s' }}
            value={form.password}
            onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
            placeholder="••••••••"
            autoComplete="current-password"
          />

          <button
            type="submit"
            disabled={isPending}
            style={{ width: '100%', padding: 12, border: 'none', borderRadius: 9, background: isPending ? '#4338ca' : '#5b4df5', color: '#fff', fontFamily: "'Instrument Sans', sans-serif", fontWeight: 700, fontSize: 14, cursor: isPending ? 'wait' : 'pointer' }}
          >
            {isPending ? 'Ingresando…' : 'Ingresar →'}
          </button>
        </form>
      </div>
    </div>
  )
}

'@ | Out-File -FilePath 'src\app\login\page.tsx' -Encoding utf8

Write-Host 'Creando src\app\dashboard\layout.tsx...'
@'
// src/app/dashboard/layout.tsx
// Verifica que el usuario sea tesorera, si no redirige

import { redirect } from 'next/navigation'
import { getCurrentAppUser } from '` @/actions/auth'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const user = await getCurrentAppUser()

  if (!user) redirect('/login')
  if (user.role !== 'tesorera') redirect('/apoderado')
  if (user.must_change_password) redirect('/change-password')

  return <>{children}</>
}

'@ | Out-File -FilePath 'src\app\dashboard\layout.tsx' -Encoding utf8

Write-Host 'Creando src\app\dashboard\page.tsx...'
@'
// src/app/dashboard/page.tsx
// Server Component — carga datos y pasa al cliente

import { getDashboardDataAction } from '` @/actions/data'
import { getCurrentAppUser } from '` @/actions/auth'
import { TesoreraDashboard } from '` @/components/TesoreraDashboard'

export default async function DashboardPage() {
  const [user, data] = await Promise.all([
    getCurrentAppUser(),
    getDashboardDataAction(),
  ])

  return (
    <TesoreraDashboard
      user={user!}
      initialStudents={data.students}
      initialQuotas={data.quotas}
      initialPayments={data.payments}
      initialExpenses={data.expenses}
      initialApoderados={data.apoderados}
    />
  )
}

'@ | Out-File -FilePath 'src\app\dashboard\page.tsx' -Encoding utf8

Write-Host 'Creando src\app\apoderado\page.tsx...'
@'
// src/app/apoderado/page.tsx

import { redirect } from 'next/navigation'
import { getCurrentAppUser } from '` @/actions/auth'
import { getApoderadoDataAction } from '` @/actions/data'
import { ApoderadoDashboard } from '` @/components/ApoderadoDashboard'

export default async function ApoderadoPage() {
  const user = await getCurrentAppUser()
  if (!user) redirect('/login')
  if (user.role !== 'apoderado') redirect('/dashboard')
  if (user.must_change_password) redirect('/change-password')

  const data = await getApoderadoDataAction()
  if (!data) redirect('/login')

  return <ApoderadoDashboard data={data} />
}

'@ | Out-File -FilePath 'src\app\apoderado\page.tsx' -Encoding utf8

Write-Host 'Creando src\app\change-password\page.tsx...'
@'
// src/app/change-password/page.tsx
'use client'

import { useState, useTransition } from 'react'
import { changePasswordAction } from '` @/actions/auth'

export default function ChangePasswordPage() {
  const [form, setForm]         = useState({ password: '', confirm: '' })
  const [error, setError]       = useState('')
  const [isPending, startTransition] = useTransition()

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    const fd = new FormData()
    fd.append('password', form.password)
    fd.append('confirm', form.confirm)
    startTransition(async () => {
      const result = await changePasswordAction(fd)
      if (result?.error) setError(result.error)
    })
  }

  return (
    <div style={{ minHeight: '100vh', background: '#f5f4fa', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'sans-serif' }}>
      <div style={{ background: '#fff', borderRadius: 16, padding: '36px 40px', width: 380, boxShadow: '0 8px 40px rgba(0,0,0,0.1)' }}>
        <div style={{ fontSize: 22, fontWeight: 900, marginBottom: 6 }}>Nueva contraseña</div>
        <div style={{ color: '#8886a0', fontSize: 13, marginBottom: 24 }}>
          Por seguridad, debes establecer tu contraseña personal antes de continuar.
        </div>

        {error && (
          <div style={{ background: '#fee2e2', borderRadius: 8, padding: '10px 12px', color: '#991b1b', fontSize: 12, fontWeight: 600, marginBottom: 14 }}>
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <label style={{ display: 'block', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.07em', color: '#8886a0', marginBottom: 5 }}>
            Nueva contraseña (mínimo 6 caracteres)
          </label>
          <input
            type="password"
            style={{ width: '100%', padding: '10px 12px', border: '1.5px solid #e8e7f0', borderRadius: 8, fontSize: 13, marginBottom: 14 }}
            value={form.password}
            onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
          />

          <label style={{ display: 'block', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.07em', color: '#8886a0', marginBottom: 5 }}>
            Repetir contraseña
          </label>
          <input
            type="password"
            style={{ width: '100%', padding: '10px 12px', border: '1.5px solid #e8e7f0', borderRadius: 8, fontSize: 13, marginBottom: 20 }}
            value={form.confirm}
            onChange={e => setForm(f => ({ ...f, confirm: e.target.value }))}
          />

          <button
            type="submit"
            disabled={isPending}
            style={{ width: '100%', padding: '11px', border: 'none', borderRadius: 9, background: '#5b4df5', color: '#fff', fontWeight: 700, fontSize: 14, cursor: 'pointer' }}
          >
            {isPending ? 'Guardando…' : 'Guardar y continuar →'}
          </button>
        </form>
      </div>
    </div>
  )
}

'@ | Out-File -FilePath 'src\app\change-password\page.tsx' -Encoding utf8

Write-Host 'Creando src\actions\auth.ts...'
@'
'use server'
// src/actions/auth.ts

import { redirect } from 'next/navigation'
import { createClient, createServiceClient } from '` @/lib/supabase/server'

// ── Construir email ficticio interno ──────────────────────────
// El usuario nunca ve esto. Formato: username@curso-COURSEID.internal
function buildFakeEmail(username: string, courseId: string) {
  return `${username}@curso-${courseId}.internal`
}

// ── LOGIN ─────────────────────────────────────────────────────
export async function loginAction(formData: FormData) {
  const username = formData.get('username') as string
  const password = formData.get('password') as string

  if (!username || !password) {
    return { error: 'Ingresa usuario y contraseña.' }
  }

  const supabase = await createClient()

  // 1. Buscar el app_user por username para obtener course_id
  //    Necesitamos el service client porque aún no hay sesión
  const service = createServiceClient()
  const { data: appUser, error: userError } = await service
    .from('app_users')
    .select('*, course_id')
    .eq('username', username)
    .single()

  if (userError || !appUser) {
    return { error: 'Usuario o contraseña incorrectos.' }
  }

  // 2. Construir email ficticio y autenticar
  const email = buildFakeEmail(username, appUser.course_id)
  const { error: authError } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (authError) {
    return { error: 'Usuario o contraseña incorrectos.' }
  }

  // 3. Redirigir según rol
  if (appUser.must_change_password) {
    redirect('/change-password')
  }

  if (appUser.role === 'tesorera') {
    redirect('/dashboard')
  } else {
    redirect('/apoderado')
  }
}

// ── LOGOUT ────────────────────────────────────────────────────
export async function logoutAction() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect('/login')
}

// ── CAMBIAR CONTRASEÑA ────────────────────────────────────────
export async function changePasswordAction(formData: FormData) {
  const password    = formData.get('password') as string
  const confirmPass = formData.get('confirm') as string

  if (!password || password.length < 4) {
    return { error: 'La contraseña debe tener al menos 4 caracteres.' }
  }
  if (password !== confirmPass) {
    return { error: 'Las contraseñas no coinciden.' }
  }

  const supabase = await createClient()

  // Actualizar clave en Supabase Auth
  const { error: authError } = await supabase.auth.updateUser({ password })
  if (authError) return { error: 'Error al cambiar la contraseña.' }

  // Marcar must_change_password = false
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    await supabase
      .from('app_users')
      .update({ must_change_password: false })
      .eq('auth_id', user.id)
  }

  redirect('/apoderado')
}

// ── OBTENER USUARIO ACTUAL ────────────────────────────────────
export async function getCurrentAppUser() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null

  const { data } = await supabase
    .from('app_users')
    .select('*')
    .eq('auth_id', user.id)
    .single()

  return data
}

// ── CREAR APODERADO (solo tesorera) ───────────────────────────
export async function createApoderadoAction(formData: FormData) {
  const username    = formData.get('username') as string
  const displayName = formData.get('display_name') as string
  const password    = formData.get('password') as string
  const studentIds  = JSON.parse(formData.get('student_ids') as string) as string[]

  if (!username || !displayName || !password || !studentIds.length) {
    return { error: 'Todos los campos son requeridos.' }
  }

  const supabase = await createClient()

  // Obtener course_id de la tesorera
  const tesorera = await getCurrentAppUser()
  if (!tesorera || tesorera.role !== 'tesorera') {
    return { error: 'Sin permisos.' }
  }

  // Verificar que el username no exista en el curso
  const { data: existing } = await supabase
    .from('app_users')
    .select('id')
    .eq('course_id', tesorera.course_id)
    .eq('username', username)
    .single()

  if (existing) return { error: 'Ese nombre de usuario ya existe en este curso.' }

  // Crear usuario en Supabase Auth (service role)
  const service = createServiceClient()
  const email = buildFakeEmail(username, tesorera.course_id)

  const { data: authData, error: authError } = await service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  })

  if (authError || !authData.user) {
    return { error: 'Error al crear el usuario.' }
  }

  // Crear app_user
  const { data: newUser, error: userError } = await service
    .from('app_users')
    .insert({
      auth_id: authData.user.id,
      course_id: tesorera.course_id,
      username,
      display_name: displayName,
      role: 'apoderado',
      must_change_password: true,
    })
    .select()
    .single()

  if (userError || !newUser) {
    // Rollback: eliminar el usuario de auth
    await service.auth.admin.deleteUser(authData.user.id)
    return { error: 'Error al guardar el apoderado.' }
  }

  // Asociar alumnos
  const relations = studentIds.map(sid => ({
    apoderado_id: newUser.id,
    student_id: sid,
  }))
  await service.from('apoderado_students').insert(relations)

  return { success: true, user: newUser }
}

// ── RESET CLAVE APODERADO ─────────────────────────────────────
export async function resetApoderadoPasswordAction(apoderadoId: string, newPassword: string = '1234') {
  const tesorera = await getCurrentAppUser()
  if (!tesorera || tesorera.role !== 'tesorera') return { error: 'Sin permisos.' }

  const service = createServiceClient()

  const { data: apoderado } = await service
    .from('app_users')
    .select('auth_id')
    .eq('id', apoderadoId)
    .eq('course_id', tesorera.course_id)
    .single()

  if (!apoderado) return { error: 'Apoderado no encontrado.' }

  await service.auth.admin.updateUserById(apoderado.auth_id, { password: newPassword })
  await service.from('app_users').update({ must_change_password: true }).eq('id', apoderadoId)

  return { success: true }
}

// ── ELIMINAR APODERADO ────────────────────────────────────────
export async function deleteApoderadoAction(apoderadoId: string) {
  const tesorera = await getCurrentAppUser()
  if (!tesorera || tesorera.role !== 'tesorera') return { error: 'Sin permisos.' }

  const service = createServiceClient()

  const { data: apoderado } = await service
    .from('app_users')
    .select('auth_id')
    .eq('id', apoderadoId)
    .eq('course_id', tesorera.course_id)
    .single()

  if (!apoderado) return { error: 'Apoderado no encontrado.' }

  // Eliminar de auth (cascada elimina app_users y apoderado_students)
  await service.auth.admin.deleteUser(apoderado.auth_id)

  return { success: true }
}

'@ | Out-File -FilePath 'src\actions\auth.ts' -Encoding utf8

Write-Host 'Creando src\actions\data.ts...'
@'
'use server'
// src/actions/data.ts
// Todas las operaciones CRUD — protegidas por RLS en Supabase

import { revalidatePath } from 'next/cache'
import { createClient } from '` @/lib/supabase/server'
import { getCurrentAppUser } from './auth'
import type { QuotaType } from '` @/lib/supabase/types'

// ─────────────────────────────────────────────────────────────
// ALUMNOS
// ─────────────────────────────────────────────────────────────

export async function getStudentsAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('students')
    .select('*')
    .order('name')
  if (error) throw error
  return data ?? []
}

export async function createStudentAction(name: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('students')
    .insert({ course_id: user.course_id, name })

  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

export async function deleteStudentAction(studentId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('students').delete().eq('id', studentId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// ─────────────────────────────────────────────────────────────
// CUOTAS
// ─────────────────────────────────────────────────────────────

export async function getQuotasAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('quotas')
    .select('*')
    .order('created_at')
  if (error) throw error
  return data ?? []
}

export async function createQuotaAction(params: {
  name: string
  type: QuotaType
  amount: number
  due_date?: string
  participant_ids: string[] | null
}) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('quotas').insert({
    course_id:       user.course_id,
    name:            params.name,
    type:            params.type,
    amount:          params.amount,
    due_date:        params.due_date || null,
    participant_ids: params.participant_ids,
  })

  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

export async function deleteQuotaAction(quotaId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('quotas').delete().eq('id', quotaId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// ─────────────────────────────────────────────────────────────
// PAGOS
// ─────────────────────────────────────────────────────────────

export async function getPaymentsAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function createPaymentAction(params: {
  student_id: string
  quota_id:   string
  paid_at:    string
}) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('payments').insert({
    course_id:  user.course_id,
    student_id: params.student_id,
    quota_id:   params.quota_id,
    paid_at:    params.paid_at,
    created_by: user.id,
  })

  // El unique constraint en (student_id, quota_id) evita duplicados
  if (error) {
    if (error.code === '23505') return { error: 'Este alumno ya tiene registrado este pago.' }
    return { error: error.message }
  }

  revalidatePath('/dashboard')
  return { success: true }
}

export async function deletePaymentAction(paymentId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('payments').delete().eq('id', paymentId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// ─────────────────────────────────────────────────────────────
// GASTOS
// ─────────────────────────────────────────────────────────────

export async function getExpensesAction() {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('expenses')
    .select('*')
    .order('date', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function createExpenseAction(params: {
  description: string
  amount:      number
  category:    string
  date:        string
}) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('expenses').insert({
    course_id:   user.course_id,
    description: params.description,
    amount:      params.amount,
    category:    params.category,
    date:        params.date,
    created_by:  user.id,
  })

  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

export async function deleteExpenseAction(expenseId: string) {
  const user = await getCurrentAppUser()
  if (!user || user.role !== 'tesorera') return { error: 'Sin permisos.' }

  const supabase = await createClient()
  const { error } = await supabase.from('expenses').delete().eq('id', expenseId)
  if (error) return { error: error.message }
  revalidatePath('/dashboard')
  return { success: true }
}

// ─────────────────────────────────────────────────────────────
// APODERADOS (lectura)
// ─────────────────────────────────────────────────────────────

export async function getApoderadosAction() {
  const supabase = await createClient()
  const { data: users, error } = await supabase
    .from('app_users')
    .select('*')
    .eq('role', 'apoderado')
    .order('display_name')

  if (error) throw error

  // Obtener alumnos de cada apoderado
  const { data: relations } = await supabase
    .from('apoderado_students')
    .select('apoderado_id, student_id, students(id, name)')

  return (users ?? []).map(u => ({
    ...u,
    students: (relations ?? [])
      .filter(r => r.apoderado_id === u.id)
      .map(r => (r as any).students)
      .filter(Boolean),
  }))
}

// ─────────────────────────────────────────────────────────────
// DATOS DEL APODERADO ACTUAL
// ─────────────────────────────────────────────────────────────

export async function getApoderadoDataAction() {
  const supabase = await createClient()
  const user = await getCurrentAppUser()
  if (!user) return null

  // Alumnos del apoderado
  const { data: relations } = await supabase
    .from('apoderado_students')
    .select('student_id, students(id, name, course_id)')
    .eq('apoderado_id', user.id)

  const students = (relations ?? []).map(r => (r as any).students).filter(Boolean)

  // Todos los datos del curso
  const [quotas, payments, expenses] = await Promise.all([
    getQuotasAction(),
    getPaymentsAction(),
    getExpensesAction(),
  ])

  return { user, students, quotas, payments, expenses }
}

// ─────────────────────────────────────────────────────────────
// TODOS LOS DATOS DEL DASHBOARD (tesorera)
// ─────────────────────────────────────────────────────────────

export async function getDashboardDataAction() {
  const [students, quotas, payments, expenses, apoderados] = await Promise.all([
    getStudentsAction(),
    getQuotasAction(),
    getPaymentsAction(),
    getExpensesAction(),
    getApoderadosAction(),
  ])
  return { students, quotas, payments, expenses, apoderados }
}

'@ | Out-File -FilePath 'src\actions\data.ts' -Encoding utf8

Write-Host 'Creando src\components\TesoreraDashboard.tsx...'
@'
'use client'
// src/components/TesoreraDashboard.tsx

import { useState, useMemo, useTransition, useCallback } from 'react'
import {
  createQuotaAction, deleteQuotaAction,
  createPaymentAction, deletePaymentAction,
  createExpenseAction, deleteExpenseAction,
  createStudentAction, deleteStudentAction,
} from '` @/actions/data'
import {
  createApoderadoAction,
  deleteApoderadoAction,
  resetApoderadoPasswordAction,
  logoutAction,
} from '` @/actions/auth'
import type {
  AppUser, Student, Quota, Payment, Expense,
  AppUserWithStudents, QuotaType,
} from '` @/lib/supabase/types'

// ─── HELPERS ──────────────────────────────────────────────────
const clp   = (n: number) => `$${Math.round(n).toLocaleString('es-CL')}`
const dateF = (s?: string | null) => s
  ? new Date(s + 'T00:00:00').toLocaleDateString('es-CL', { day: '2-digit', month: 'short', year: 'numeric' })
  : '—'
const nowDate = () => new Date().toISOString().split('T')[0]

const quotaParticipants = (q: Quota, students: Student[]) =>
  q.participant_ids ?? students.map(s => s.id)

const isParticipant = (q: Quota, sid: string, students: Student[]) =>
  quotaParticipants(q, students).includes(sid)

// ─── TIPOS PROPS ──────────────────────────────────────────────
interface Props {
  user:               AppUser
  initialStudents:    Student[]
  initialQuotas:      Quota[]
  initialPayments:    Payment[]
  initialExpenses:    Expense[]
  initialApoderados:  AppUserWithStudents[]
}

// ─── PDF ──────────────────────────────────────────────────────
function generatePDF(
  students: Student[], quotas: Quota[],
  payments: Payment[], expenses: Expense[]
) {
  const totalIncome  = payments.reduce((s, p) => { const q = quotas.find(q => q.id === p.quota_id); return s + (q?.amount ?? 0) }, 0)
  const totalExpense = expenses.reduce((s, e) => s + e.amount, 0)
  const balance      = totalIncome - totalExpense
  const totalExpected = quotas.reduce((s, q) => s + q.amount * quotaParticipants(q, students).length, 0)
  const globalPct     = totalExpected > 0 ? Math.round((totalIncome / totalExpected) * 100) : 0
  const today         = new Date().toLocaleDateString('es-CL', { day: '2-digit', month: 'long', year: 'numeric' })
  const hasPaid       = (sid: string, qid: string) => payments.some(p => p.student_id === sid && p.quota_id === qid)

  const qHeaders = quotas.map(q => `
    <th style="text-align:center;padding:8px 6px;font-size:10px;text-transform:uppercase;letter-spacing:0.05em;color:#8886a0;">
      ${q.name}<br/><span style="font-size:9px;font-weight:400;color:#aaa;">
      ${q.participant_ids === null ? 'Todos' : `${q.participant_ids.length} alumnos`}</span>
    </th>`).join('')

  const rows = students.map(s => {
    const cells = quotas.map(q => {
      const applies = isParticipant(q, s.id, students)
      if (!applies) return `<td style="text-align:center;color:#aaa;font-size:11px;">—</td>`
      const paid = hasPaid(s.id, q.id)
      return `<td style="text-align:center;"><span style="display:inline-block;padding:2px 8px;border-radius:99px;font-size:10px;font-weight:700;background:${paid ? '#d1fae5' : '#fee2e2'};color:${paid ? '#065f46' : '#991b1b'};">${paid ? '✓ Pagado' : 'Pendiente'}</span></td>`
    }).join('')
    const myTotal = payments.filter(p => p.student_id === s.id)
      .reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
    return `<tr><td style="font-weight:600;padding:8px 10px;">${s.name}</td>${cells}<td style="text-align:center;font-weight:700;color:#5b4df5;">${clp(myTotal)}</td></tr>`
  }).join('')

  const projRows = quotas.map(q => {
    const parts = quotaParticipants(q, students)
    const exp   = q.amount * parts.length
    const paid  = payments.filter(p => p.quota_id === q.id && parts.includes(p.student_id)).length * q.amount
    const pct   = exp > 0 ? Math.round((paid / exp) * 100) : 0
    return `<tr>
      <td style="padding:7px 10px;font-weight:600;">${q.name}</td>
      <td style="padding:7px 10px;text-align:center;">${parts.length} de ${students.length}</td>
      <td style="padding:7px 10px;text-align:right;">${clp(exp)}</td>
      <td style="padding:7px 10px;text-align:right;color:#059669;font-weight:600;">${clp(paid)}</td>
      <td style="padding:7px 10px;text-align:right;color:#dc2626;">${clp(exp - paid)}</td>
      <td style="padding:7px 10px;text-align:center;font-weight:700;color:${pct === 100 ? '#059669' : pct >= 60 ? '#5b4df5' : '#d97706'}">${pct}%</td>
    </tr>`
  }).join('')

  const expRows = expenses.map(e => `
    <tr>
      <td style="padding:7px 10px;">${e.description}</td>
      <td style="padding:7px 10px;">${e.category}</td>
      <td style="padding:7px 10px;text-align:right;font-weight:600;color:#dc2626;">-${clp(e.amount)}</td>
      <td style="padding:7px 10px;color:#888;">${dateF(e.date)}</td>
    </tr>`).join('')

  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"/>
<title>Informe Tesorería</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@700;900&family=Instrument+Sans:wght@400;600;700&display=swap');
  *{box-sizing:border-box;margin:0;padding:0;}
  body{font-family:'Instrument Sans',sans-serif;color:#0d0d12;background:#fff;padding:40px 48px;font-size:13px;}
  h1{font-family:'Fraunces',serif;font-size:28px;font-weight:900;letter-spacing:-0.03em;margin-bottom:2px;}
  h2{font-family:'Fraunces',serif;font-size:16px;font-weight:700;margin:28px 0 12px;border-bottom:2px solid #e8e7f0;padding-bottom:6px;}
  .meta{color:#888;font-size:12px;margin-bottom:24px;}
  .kpis{display:flex;gap:16px;margin-bottom:24px;}
  .kpi{flex:1;border-radius:10px;padding:14px 16px;}
  .kpi label{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:0.07em;display:block;margin-bottom:4px;}
  .kpi span{font-family:'Fraunces',serif;font-size:22px;font-weight:900;}
  .ki{background:#ede9ff;color:#5b4df5;} .kg{background:#d1fae5;color:#059669;}
  .kr{background:#fee2e2;color:#dc2626;} .ka{background:#fef3c7;color:#d97706;}
  table{width:100%;border-collapse:collapse;margin-bottom:8px;}
  th{background:#f5f4fa;text-align:left;padding:8px 10px;font-size:10px;text-transform:uppercase;letter-spacing:0.05em;color:#8886a0;}
  td{padding:8px 10px;border-bottom:1px solid #f3f3f8;}
  tr:last-child td{border-bottom:none;}
  .prog{height:6px;background:#e8e7f0;border-radius:99px;overflow:hidden;margin-top:10px;}
  .prog div{height:100%;border-radius:99px;}
  .footer{margin-top:36px;border-top:1px solid #e8e7f0;padding-top:12px;font-size:10px;color:#aaa;display:flex;justify-content:space-between;}
  @media print{body{padding:20px 28px;}}
</style></head><body>
  <h1>Tesorería Curso</h1>
  <div class="meta">Generado el ${today}</div>
  <div class="kpis">
    <div class="kpi ki"><label>Saldo disponible</label><span>${clp(balance)}</span></div>
    <div class="kpi kg"><label>Total recaudado</label><span>${clp(totalIncome)}</span></div>
    <div class="kpi kr"><label>Total gastado</label><span>${clp(totalExpense)}</span></div>
    <div class="kpi ka"><label>Esperado total</label><span>${clp(totalExpected)}</span></div>
  </div>
  <div class="prog"><div style="width:${globalPct}%;background:${globalPct >= 80 ? '#059669' : globalPct >= 50 ? '#5b4df5' : '#d97706'};"></div></div>
  <p style="font-size:11px;color:#888;margin-top:5px;margin-bottom:24px;">Avance: <strong style="color:#0d0d12">${globalPct}%</strong></p>
  <h2>Estado de pagos por alumno</h2>
  <table><thead><tr><th style="min-width:140px;">Alumno</th>${qHeaders}<th style="text-align:center;">Total pagado</th></tr></thead><tbody>${rows}</tbody></table>
  <h2>Proyección por cuota</h2>
  <table><thead><tr><th>Cuota</th><th style="text-align:center;">Participantes</th><th style="text-align:right;">Esperado</th><th style="text-align:right;">Recaudado</th><th style="text-align:right;">Por cobrar</th><th style="text-align:center;">Avance</th></tr></thead><tbody>${projRows}</tbody></table>
  <h2>Gastos registrados</h2>
  <table><thead><tr><th>Descripción</th><th>Categoría</th><th style="text-align:right;">Monto</th><th>Fecha</th></tr></thead>
  <tbody>${expRows}</tbody>
  <tfoot><tr><td colspan="2" style="font-weight:700;padding:10px;">Total gastado</td><td style="text-align:right;font-weight:700;color:#dc2626;padding:10px;">-${clp(totalExpense)}</td><td></td></tr></tfoot></table>
  <div class="footer"><span>Tesorería Curso</span><span>${today}</span></div>
</body></html>`

  const win = window.open('', '_blank')!
  win.document.write(html)
  win.document.close()
  win.onload = () => win.print()
}

// ─── MODAL ────────────────────────────────────────────────────
function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode }) {
  return (
    <div className="overlay">
      <div className="modal">
        <div className="modal-header">
          <div className="modal-title">{title}</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        {children}
      </div>
    </div>
  )
}

// ─── STUDENT PICKER ───────────────────────────────────────────
function StudentPicker({ students, selected, onChange }: { students: Student[]; selected: string[]; onChange: (v: string[]) => void }) {
  const toggle = (id: string) =>
    onChange(selected.includes(id) ? selected.filter(s => s !== id) : [...selected, id])
  return (
    <div>
      <div className="check-all">
        <button type="button" className="check-tag" onClick={() => onChange(students.map(s => s.id))}>Todos</button>
        <button type="button" className="check-tag" onClick={() => onChange([])}>Ninguno</button>
      </div>
      <div className="check-grid">
        {students.map(s => (
          <label key={s.id} className={`check-item ${selected.includes(s.id) ? 'checked' : ''}`}>
            <input type="checkbox" checked={selected.includes(s.id)} onChange={() => toggle(s.id)} />
            {s.name}
          </label>
        ))}
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// COMPONENTE PRINCIPAL
// ─────────────────────────────────────────────────────────────
export function TesoreraDashboard({
  user,
  initialStudents, initialQuotas, initialPayments,
  initialExpenses, initialApoderados,
}: Props) {
  const [tab,        setTab]        = useState('resumen')
  const [students,   setStudents]   = useState(initialStudents)
  const [quotas,     setQuotas]     = useState(initialQuotas)
  const [payments,   setPayments]   = useState(initialPayments)
  const [expenses,   setExpenses]   = useState(initialExpenses)
  const [apoderados, setApoderados] = useState(initialApoderados)
  const [modal,      setModal]      = useState<string | null>(null)
  const [form,       setForm]       = useState<Record<string, any>>({})
  const [err,        setErr]        = useState('')
  const [isPending,  startTransition] = useTransition()

  const setF = (k: string, v: any) => setForm(f => ({ ...f, [k]: v }))
  const openModal = (name: string, initial: Record<string, any> = {}) => {
    setForm(initial); setErr(''); setModal(name)
  }
  const closeModal = () => { setModal(null); setErr('') }

  // ── Cálculos ───────────────────────────────────────────────
  const totalIncome  = useMemo(() => payments.reduce((s, p) => { const q = quotas.find(q => q.id === p.quota_id); return s + (q?.amount ?? 0) }, 0), [payments, quotas])
  const totalExpense = useMemo(() => expenses.reduce((s, e) => s + e.amount, 0), [expenses])
  const balance      = totalIncome - totalExpense

  const projection = useMemo(() => quotas.map(q => {
    const parts    = quotaParticipants(q, students)
    const expected = q.amount * parts.length
    const paid     = payments.filter(p => p.quota_id === q.id && parts.includes(p.student_id)).length * q.amount
    const pct      = expected > 0 ? Math.round((paid / expected) * 100) : 0
    return { ...q, parts, expected, paid, pct, missing: expected - paid }
  }), [quotas, payments, students])

  const totalExpected = projection.reduce((s, p) => s + p.expected, 0)
  const globalPct     = totalExpected > 0 ? Math.round((totalIncome / totalExpected) * 100) : 0

  const hasPaid = useCallback((sid: string, qid: string) =>
    payments.some(p => p.student_id === sid && p.quota_id === qid), [payments])

  // ── Acciones ───────────────────────────────────────────────
  const run = (fn: () => Promise<any>, onOk: () => void) => {
    startTransition(async () => {
      const res = await fn()
      if (res?.error) { setErr(res.error); return }
      onOk()
      closeModal()
    })
  }

  const handleSaveQuota = () => {
    const participant_ids: string[] | null =
      form.q_type === 'especial'
        ? (form.q_all ? null : (form.q_participants?.length ? form.q_participants : null))
        : null
    run(
      () => createQuotaAction({ name: form.q_name, type: form.q_type as QuotaType, amount: Number(form.q_amount), due_date: form.q_due_date, participant_ids }),
      () => setQuotas(qs => [...qs, { id: 'tmp-' + Date.now(), course_id: user.id, name: form.q_name, type: form.q_type, amount: Number(form.q_amount), due_date: form.q_due_date || null, participant_ids, created_at: new Date().toISOString() }])
    )
  }

  const handleDeleteQuota = (id: string) => {
    run(() => deleteQuotaAction(id), () => setQuotas(qs => qs.filter(q => q.id !== id)))
  }

  const handleSavePago = () => {
    run(
      () => createPaymentAction({ student_id: form.student_id, quota_id: form.quota_id, paid_at: form.paid_at || nowDate() }),
      () => setPayments(ps => [...ps, { id: 'tmp-' + Date.now(), course_id: user.id, student_id: form.student_id, quota_id: form.quota_id, paid_at: form.paid_at || nowDate(), created_by: user.id, created_at: new Date().toISOString() }])
    )
  }

  const handleDeletePago = (id: string) => {
    run(() => deletePaymentAction(id), () => setPayments(ps => ps.filter(p => p.id !== id)))
  }

  const handleSaveExpense = () => {
    run(
      () => createExpenseAction({ description: form.e_desc, amount: Number(form.e_amount), category: form.e_category || 'Otro', date: form.e_date || nowDate() }),
      () => setExpenses(es => [...es, { id: 'tmp-' + Date.now(), course_id: user.id, description: form.e_desc, amount: Number(form.e_amount), category: form.e_category || 'Otro', date: form.e_date || nowDate(), created_by: user.id, created_at: new Date().toISOString() }])
    )
  }

  const handleDeleteExpense = (id: string) => {
    run(() => deleteExpenseAction(id), () => setExpenses(es => es.filter(e => e.id !== id)))
  }

  const handleSaveStudent = () => {
    if (!form.s_name?.trim()) return
    run(
      () => createStudentAction(form.s_name.trim()),
      () => setStudents(ss => [...ss, { id: 'tmp-' + Date.now(), course_id: user.id, name: form.s_name.trim(), created_at: new Date().toISOString() }])
    )
  }

  const handleDeleteStudent = (id: string) => {
    run(() => deleteStudentAction(id), () => setStudents(ss => ss.filter(s => s.id !== id)))
  }

  const handleSaveApoderado = () => {
    const fd = new FormData()
    fd.append('username', form.ap_user || '')
    fd.append('display_name', form.ap_name || '')
    fd.append('password', form.ap_pass || '')
    fd.append('student_ids', JSON.stringify(form.ap_students || []))
    run(
      () => createApoderadoAction(fd),
      () => {
        const hijos = students.filter(s => (form.ap_students || []).includes(s.id))
        setApoderados(ap => [...ap, { id: 'tmp-' + Date.now(), auth_id: '', course_id: user.id, username: form.ap_user, display_name: form.ap_name, role: 'apoderado', must_change_password: true, created_at: new Date().toISOString(), students: hijos }])
      }
    )
  }

  const handleDeleteApoderado = (id: string) => {
    run(() => deleteApoderadoAction(id), () => setApoderados(ap => ap.filter(a => a.id !== id)))
  }

  const handleResetApoderado = (id: string) => {
    run(() => resetApoderadoPasswordAction(id), () => setApoderados(ap => ap.map(a => a.id === id ? { ...a, must_change_password: true } : a)))
  }

  // ── Cuota en modal pago ────────────────────────────────────
  const quotaForPago    = form.quota_id ? quotas.find(q => q.id === form.quota_id) : null
  const eligibleForPago = quotaForPago ? quotaParticipants(quotaForPago, students) : students.map(s => s.id)

  const TABS = [
    { id: 'resumen',    label: 'Resumen' },
    { id: 'cuotas',     label: 'Cuotas' },
    { id: 'pagos',      label: 'Pagos' },
    { id: 'gastos',     label: 'Gastos' },
    { id: 'proyeccion', label: 'Proyección' },
    { id: 'alumnos',    label: 'Alumnos' },
    { id: 'apoderados', label: 'Apoderados' },
  ]

  return (
    <div>
      {/* TOPBAR */}
      <div className="topbar no-print">
        <div>
          <div className="topbar-title">🏦 Tesorería <span>Curso</span></div>
          <div className="topbar-sub">Vista Tesorera · {user.display_name}</div>
        </div>
        <nav className="topbar-nav">
          {TABS.map(t => (
            <button key={t.id} className={`nav-btn ${tab === t.id ? 'active' : 'inactive'}`} onClick={() => setTab(t.id)}>
              {t.label}
            </button>
          ))}
        </nav>
        <div className="topbar-right">
          <button className="btn btn-green btn-sm" onClick={() => generatePDF(students, quotas, payments, expenses)}>📄 PDF</button>
          <button className="btn btn-ghost btn-sm" onClick={() => startTransition(() => logoutAction())}>Salir</button>
        </div>
      </div>

      <div className="content">

        {/* ══ RESUMEN ══ */}
        {tab === 'resumen' && (
          <>
            <div className="card-grid card-grid-3 mb-4">
              {[
                { label: 'Saldo disponible', value: clp(balance),      cls: 'kpi-indigo', sub: `${totalIncome > 0 ? Math.round(balance / totalIncome * 100) : 0}% de lo recaudado` },
                { label: 'Total recaudado',  value: clp(totalIncome),  cls: 'kpi-green',  sub: `${payments.length} pagos registrados` },
                { label: 'Total gastado',    value: clp(totalExpense), cls: 'kpi-red',    sub: `${expenses.length} gastos` },
              ].map(k => (
                <div key={k.label} className={`kpi ${k.cls}`}>
                  <div className="kpi-label">{k.label}</div>
                  <div className="kpi-value">{k.value}</div>
                  <div className="kpi-sub">{k.sub}</div>
                </div>
              ))}
            </div>
            <div className="card-grid card-grid-2 mb-4">
              <div className="card">
                <div className="card-title">Últimos pagos</div>
                <table className="tbl">
                  <thead><tr><th>Alumno</th><th>Cuota</th><th>Fecha</th></tr></thead>
                  <tbody>
                    {[...payments].reverse().slice(0, 6).map(p => {
                      const q = quotas.find(q => q.id === p.quota_id)
                      const s = students.find(s => s.id === p.student_id)
                      return (
                        <tr key={p.id}>
                          <td className="fw-700 fs-13">{s?.name}</td>
                          <td><span className={`badge ${q?.type === 'especial' ? 'badge-blue' : 'badge-indigo'}`}>{q?.name}</span></td>
                          <td className="fs-12 c-muted">{dateF(p.paid_at)}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
              <div className="card">
                <div className="card-title">Últimos gastos</div>
                <table className="tbl">
                  <thead><tr><th>Descripción</th><th>Monto</th><th>Fecha</th></tr></thead>
                  <tbody>
                    {[...expenses].reverse().slice(0, 6).map(e => (
                      <tr key={e.id}>
                        <td className="fw-700 fs-13">{e.description}</td>
                        <td className="fw-700 c-red">-{clp(e.amount)}</td>
                        <td className="fs-12 c-muted">{dateF(e.date)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <div className="card">
              <div className="row mb-4">
                <div className="card-title" style={{ marginBottom: 0 }}>Recaudación global</div>
                <span className="fw-700 fs-13 c-indigo">{globalPct}% del esperado</span>
              </div>
              <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${globalPct}%`, background: globalPct >= 80 ? 'var(--green)' : globalPct >= 50 ? 'var(--indigo)' : 'var(--amber)' }} />
              </div>
              <div className="row mt-3">
                <span className="fs-12 c-muted">Esperado: {clp(totalExpected)}</span>
                <span className="fs-12 c-muted">Por cobrar: <strong className="c-red">{clp(totalExpected - totalIncome)}</strong></span>
              </div>
            </div>
          </>
        )}

        {/* ══ CUOTAS ══ */}
        {tab === 'cuotas' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Cuotas definidas</div>
              <button className="btn btn-primary" onClick={() => openModal('quota', { q_participants: [] })}>+ Nueva cuota</button>
            </div>
            <table className="tbl">
              <thead><tr><th>Nombre</th><th>Tipo</th><th>Monto</th><th>Participantes</th><th>Vencimiento</th><th>Recaudado</th><th>Estado</th><th></th></tr></thead>
              <tbody>
                {quotas.map(q => {
                  const parts     = quotaParticipants(q, students)
                  const paidCount = payments.filter(p => p.quota_id === q.id && parts.includes(p.student_id)).length
                  const pending   = parts.length - paidCount
                  return (
                    <tr key={q.id}>
                      <td className="fw-700 fs-13">{q.name}</td>
                      <td><span className={`badge ${q.type === 'mensual' ? 'badge-indigo' : 'badge-blue'}`}>{q.type === 'mensual' ? 'Mensual' : 'Especial'}</span></td>
                      <td className="fw-700 c-green">{clp(q.amount)}</td>
                      <td><span className="badge badge-gray">{q.participant_ids === null ? `Todo el curso (${students.length})` : `${parts.length} de ${students.length}`}</span></td>
                      <td className="fs-12 c-muted">{dateF(q.due_date)}</td>
                      <td className="fw-700 c-green">{clp(paidCount * q.amount)}</td>
                      <td><span className={`badge ${pending > 0 ? 'badge-amber' : 'badge-green'}`}>{pending > 0 ? `${pending} pendiente${pending > 1 ? 's' : ''}` : '✓ Completo'}</span></td>
                      <td><button className="btn-red-sm" onClick={() => handleDeleteQuota(q.id)}>Eliminar</button></td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* ══ PAGOS ══ */}
        {tab === 'pagos' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Estado de pagos por alumno</div>
              <button className="btn btn-primary" onClick={() => openModal('pago')}>+ Registrar pago</button>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table className="tbl">
                <thead>
                  <tr>
                    <th style={{ minWidth: 150 }}>Alumno</th>
                    {quotas.map(q => (
                      <th key={q.id} style={{ minWidth: 110, textAlign: 'center' }}>
                        {q.name}
                        <div style={{ fontWeight: 400, color: 'var(--muted)', marginTop: 1, fontSize: 9 }}>
                          {q.participant_ids === null ? 'Todos' : `${q.participant_ids.length} alumnos`}
                        </div>
                      </th>
                    ))}
                    <th style={{ textAlign: 'center' }}>Total pagado</th>
                  </tr>
                </thead>
                <tbody>
                  {students.map(s => {
                    const myPays = payments.filter(p => p.student_id === s.id)
                    const total  = myPays.reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
                    return (
                      <tr key={s.id}>
                        <td className="fw-700 fs-13">{s.name}</td>
                        {quotas.map(q => {
                          const belongs = isParticipant(q, s.id, students)
                          const paid    = hasPaid(s.id, q.id)
                          const pay     = myPays.find(p => p.quota_id === q.id)
                          return (
                            <td key={q.id} style={{ textAlign: 'center' }}>
                              {!belongs
                                ? <span className="badge badge-gray">No aplica</span>
                                : paid
                                  ? <button className="badge badge-green" style={{ cursor: 'pointer', border: 'none' }} title={`Pagado ${dateF(pay?.paid_at)}`} onClick={() => pay && handleDeletePago(pay.id)}>✓ Pagado</button>
                                  : <span className="badge badge-red">Pendiente</span>
                              }
                            </td>
                          )
                        })}
                        <td style={{ textAlign: 'center' }} className="fw-700 c-indigo">{clp(total)}</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <p style={{ fontSize: 10, color: 'var(--muted)', marginTop: 10 }}>💡 Haz clic en "✓ Pagado" para anular un pago.</p>
          </div>
        )}

        {/* ══ GASTOS ══ */}
        {tab === 'gastos' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Gastos registrados</div>
              <button className="btn btn-danger" onClick={() => openModal('gasto')}>+ Registrar gasto</button>
            </div>
            {balance < 0 && <div className="alert alert-red">⚠️ Saldo negativo: los gastos superan lo recaudado en {clp(Math.abs(balance))}.</div>}
            {balance >= 0 && balance < totalExpense * 0.2 && totalExpense > 0 && <div className="alert alert-amber">⚠️ Saldo bajo: quedan {clp(balance)} disponibles.</div>}
            <table className="tbl">
              <thead><tr><th>Descripción</th><th>Categoría</th><th>Monto</th><th>Fecha</th><th></th></tr></thead>
              <tbody>
                {[...expenses].reverse().map(e => (
                  <tr key={e.id}>
                    <td className="fw-700 fs-13">{e.description}</td>
                    <td><span className="badge badge-indigo">{e.category}</span></td>
                    <td className="fw-700 c-red">-{clp(e.amount)}</td>
                    <td className="fs-12 c-muted">{dateF(e.date)}</td>
                    <td><button className="btn-red-sm" onClick={() => handleDeleteExpense(e.id)}>Eliminar</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
            {expenses.length === 0 && <div style={{ textAlign: 'center', color: 'var(--muted)', fontSize: 13, padding: '20px 0' }}>Sin gastos registrados</div>}
            <div className="divider" />
            <div className="row"><span className="fs-13 c-muted">Total gastado</span><span className="fw-700 c-red" style={{ fontSize: 17, fontFamily: "'Fraunces',serif" }}>{clp(totalExpense)}</span></div>
            <div className="row mt-3"><span className="fs-13 c-muted">Saldo disponible</span><span className="fw-700" style={{ fontSize: 17, fontFamily: "'Fraunces',serif", color: balance >= 0 ? 'var(--green)' : 'var(--red)' }}>{clp(balance)}</span></div>
          </div>
        )}

        {/* ══ PROYECCIÓN ══ */}
        {tab === 'proyeccion' && (
          <>
            <div className="card-grid card-grid-3 mb-4">
              <div className="kpi kpi-indigo"><div className="kpi-label">Recaudación esperada</div><div className="kpi-value">{clp(totalExpected)}</div><div className="kpi-sub">Según participantes</div></div>
              <div className="kpi kpi-green"><div className="kpi-label">Recaudado hasta hoy</div><div className="kpi-value">{clp(totalIncome)}</div><div className="kpi-sub">{globalPct}% del esperado</div></div>
              <div className="kpi kpi-amber"><div className="kpi-label">Falta por recaudar</div><div className="kpi-value">{clp(totalExpected - totalIncome)}</div><div className="kpi-sub">{100 - globalPct}% pendiente</div></div>
            </div>
            <div className="card mb-4">
              <div className="row mb-3"><div className="card-title" style={{ marginBottom: 0 }}>Avance global</div><span className="fw-700 c-indigo">{globalPct}%</span></div>
              <div className="progress-bar" style={{ height: 12 }}>
                <div className="progress-fill" style={{ width: `${globalPct}%`, background: globalPct >= 80 ? 'var(--green)' : globalPct >= 50 ? 'var(--indigo)' : 'var(--amber)' }} />
              </div>
            </div>
            <div className="card">
              <div className="card-title">Por cuota</div>
              {projection.map(p => (
                <div key={p.id} style={{ marginBottom: 22 }}>
                  <div className="row mb-3">
                    <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
                      <span className="fw-700 fs-13">{p.name}</span>
                      <span className={`badge ${p.type === 'mensual' ? 'badge-indigo' : 'badge-blue'}`}>{p.type === 'mensual' ? 'Mensual' : 'Especial'}</span>
                      <span className="badge badge-gray">👥 {p.participant_ids === null ? 'Todo el curso' : `${p.parts.length} de ${students.length}`}</span>
                    </div>
                    <span className="fw-700 fs-13 c-indigo">{p.pct}%</span>
                  </div>
                  <div className="progress-bar">
                    <div className="progress-fill" style={{ width: `${p.pct}%`, background: p.pct === 100 ? 'var(--green)' : p.pct >= 60 ? 'var(--indigo)' : 'var(--amber)' }} />
                  </div>
                  <div className="row mt-3" style={{ fontSize: 11, color: 'var(--muted)' }}>
                    <span>Esperado: {clp(p.expected)} · Recaudado: <strong style={{ color: 'var(--green)' }}>{clp(p.paid)}</strong></span>
                    <span style={{ color: 'var(--red)' }}>Falta: <strong>{clp(p.missing)}</strong></span>
                  </div>
                </div>
              ))}
              <div className="divider" />
              <div style={{ background: 'var(--bg)', borderRadius: 10, padding: '14px 16px' }}>
                {[
                  { label: 'Recaudación esperada', val: clp(totalExpected), color: 'var(--ink)' },
                  { label: 'Ya recaudado', val: clp(totalIncome), color: 'var(--green)' },
                  { label: 'Por recaudar', val: clp(totalExpected - totalIncome), color: 'var(--amber)' },
                  { label: 'Total gastado', val: clp(totalExpense), color: 'var(--red)' },
                  { label: 'Saldo actual', val: clp(balance), color: balance >= 0 ? 'var(--green)' : 'var(--red)' },
                  { label: 'Saldo proyectado (si todos pagan)', val: clp(totalExpected - totalExpense), color: totalExpected >= totalExpense ? 'var(--green)' : 'var(--red)' },
                ].map(r => (
                  <div key={r.label} className="row mb-3">
                    <span className="fs-13 c-muted">{r.label}</span>
                    <span className="fw-700 fs-13" style={{ color: r.color, fontFamily: "'Fraunces',serif" }}>{r.val}</span>
                  </div>
                ))}
              </div>
            </div>
          </>
        )}

        {/* ══ ALUMNOS ══ */}
        {tab === 'alumnos' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Alumnos del curso ({students.length})</div>
              <button className="btn btn-primary" onClick={() => openModal('alumno')}>+ Agregar alumno</button>
            </div>
            <table className="tbl">
              <thead><tr><th>Nombre</th><th>Cuotas pagadas</th><th>Total pagado</th><th></th></tr></thead>
              <tbody>
                {students.map(s => {
                  const myPays   = payments.filter(p => p.student_id === s.id)
                  const myTotal  = myPays.reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
                  return (
                    <tr key={s.id}>
                      <td className="fw-700 fs-13">{s.name}</td>
                      <td><span className="badge badge-indigo">{myPays.length} pagos</span></td>
                      <td className="fw-700 c-green">{clp(myTotal)}</td>
                      <td><button className="btn-red-sm" onClick={() => handleDeleteStudent(s.id)}>Eliminar</button></td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* ══ APODERADOS ══ */}
        {tab === 'apoderados' && (
          <div className="card">
            <div className="row mb-4">
              <div className="card-title" style={{ marginBottom: 0 }}>Gestión de apoderados</div>
              <button className="btn btn-primary" onClick={() => openModal('apoderado', { ap_students: [] })}>+ Crear apoderado</button>
            </div>
            <div className="alert alert-blue mb-4">
              ℹ️ La contraseña inicial se entrega al apoderado. Al primer ingreso, el sistema le pedirá que la cambie.
            </div>
            <table className="tbl">
              <thead><tr><th>Nombre</th><th>Usuario</th><th>Alumno(s)</th><th>Estado</th><th>Acciones</th></tr></thead>
              <tbody>
                {apoderados.map(a => (
                  <tr key={a.id}>
                    <td className="fw-700 fs-13">{a.display_name}</td>
                    <td className="fs-12 c-muted" style={{ fontFamily: 'monospace' }}>{a.username}</td>
                    <td>{a.students?.map(h => <span key={h.id} className="badge badge-indigo" style={{ marginRight: 3 }}>{h.name}</span>)}</td>
                    <td><span className={`badge ${a.must_change_password ? 'badge-amber' : 'badge-green'}`}>{a.must_change_password ? 'Debe cambiar clave' : 'Activo'}</span></td>
                    <td style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-ghost btn-sm" onClick={() => handleResetApoderado(a.id)}>Reset clave</button>
                      <button className="btn-red-sm" onClick={() => handleDeleteApoderado(a.id)}>Eliminar</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ══ MODALES ══ */}

      {modal === 'quota' && (
        <Modal title="Nueva cuota" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Nombre</label>
          <input className="form-input" placeholder="ej: Cuota Junio" value={form.q_name || ''} onChange={e => setF('q_name', e.target.value)} />
          <label className="form-label">Tipo</label>
          <select className="form-input" value={form.q_type || ''} onChange={e => { setF('q_type', e.target.value); setF('q_participants', []); setF('q_all', false) }}>
            <option value="">— seleccionar —</option>
            <option value="mensual">Mensual (todo el curso)</option>
            <option value="especial">Especial (viaje, evento…)</option>
          </select>
          {form.q_type === 'especial' && (
            <div style={{ marginBottom: 12 }}>
              <label className="form-label">¿Quiénes participan?</label>
              <div style={{ display: 'flex', gap: 12, marginBottom: 10 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, cursor: 'pointer' }}>
                  <input type="radio" name="q_scope" checked={!!form.q_all} onChange={() => { setF('q_all', true); setF('q_participants', []) }} /> Todo el curso
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, cursor: 'pointer' }}>
                  <input type="radio" name="q_scope" checked={!form.q_all} onChange={() => setF('q_all', false)} /> Seleccionar alumnos
                </label>
              </div>
              {!form.q_all && <StudentPicker students={students} selected={form.q_participants || []} onChange={v => setF('q_participants', v)} />}
              {!form.q_all && (form.q_participants || []).length > 0 && <div className="alert alert-blue" style={{ fontSize: 11 }}>{(form.q_participants || []).length} alumno(s) seleccionados</div>}
            </div>
          )}
          <label className="form-label">Monto por alumno (CLP)</label>
          <input className="form-input" type="number" min="1" value={form.q_amount || ''} onChange={e => setF('q_amount', e.target.value)} />
          {form.q_amount && (
            <div className="alert alert-green" style={{ fontSize: 11 }}>
              Recaudación esperada: <strong>{clp(Number(form.q_amount) * (form.q_type === 'mensual' || form.q_all ? students.length : (form.q_participants || []).length))}</strong>
            </div>
          )}
          <label className="form-label">Vencimiento (opcional)</label>
          <input className="form-input" type="date" value={form.q_due_date || ''} onChange={e => setF('q_due_date', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.q_name || !form.q_amount || !form.q_type || (form.q_type === 'especial' && !form.q_all && !(form.q_participants || []).length)} onClick={handleSaveQuota}>
              {isPending ? 'Guardando…' : 'Crear cuota'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'pago' && (
        <Modal title="Registrar pago" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Cuota</label>
          <select className="form-input" value={form.quota_id || ''} onChange={e => { setF('quota_id', e.target.value); setF('student_id', '') }}>
            <option value="">— seleccionar —</option>
            {quotas.map(q => <option key={q.id} value={q.id}>{q.name} — {clp(q.amount)}</option>)}
          </select>
          <label className="form-label">Alumno</label>
          <select className="form-input" value={form.student_id || ''} onChange={e => setF('student_id', e.target.value)} disabled={!form.quota_id}>
            <option value="">— seleccionar —</option>
            {students.filter(s => eligibleForPago.includes(s.id)).map(s => {
              const paid = hasPaid(s.id, form.quota_id)
              return <option key={s.id} value={s.id} disabled={paid}>{s.name}{paid ? ' ✓ ya pagó' : ''}</option>
            })}
          </select>
          {quotaForPago?.participant_ids !== null && form.quota_id && (
            <div className="alert alert-blue" style={{ fontSize: 11 }}>Esta cuota aplica solo a {quotaParticipants(quotaForPago!, students).length} de {students.length} alumnos.</div>
          )}
          <label className="form-label">Fecha de pago</label>
          <input className="form-input" type="date" value={form.paid_at || nowDate()} onChange={e => setF('paid_at', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.student_id || !form.quota_id || hasPaid(form.student_id, form.quota_id)} onClick={handleSavePago}>
              {isPending ? 'Guardando…' : 'Registrar'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'gasto' && (
        <Modal title="Registrar gasto" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          {balance <= 0 && <div className="alert alert-amber">⚠️ Saldo actual: {clp(balance)}.</div>}
          <label className="form-label">Descripción</label>
          <input className="form-input" value={form.e_desc || ''} onChange={e => setF('e_desc', e.target.value)} />
          <label className="form-label">Categoría</label>
          <select className="form-input" value={form.e_category || ''} onChange={e => setF('e_category', e.target.value)}>
            <option value="">— seleccionar —</option>
            {['Material', 'Reunión', 'Evento', 'Viaje', 'Otro'].map(c => <option key={c}>{c}</option>)}
          </select>
          <label className="form-label">Monto (CLP)</label>
          <input className="form-input" type="number" min="1" value={form.e_amount || ''} onChange={e => setF('e_amount', e.target.value)} />
          {form.e_amount && <div className="alert alert-green" style={{ fontSize: 11 }}>Saldo después: <strong>{clp(balance - Number(form.e_amount))}</strong></div>}
          <label className="form-label">Fecha</label>
          <input className="form-input" type="date" value={form.e_date || nowDate()} onChange={e => setF('e_date', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-danger" disabled={isPending || !form.e_desc || !form.e_amount} onClick={handleSaveExpense}>
              {isPending ? 'Guardando…' : 'Registrar gasto'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'alumno' && (
        <Modal title="Agregar alumno" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Nombre completo</label>
          <input className="form-input" placeholder="ej: Valentina Mora" value={form.s_name || ''} onChange={e => setF('s_name', e.target.value)} />
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.s_name?.trim()} onClick={handleSaveStudent}>
              {isPending ? 'Guardando…' : 'Agregar'}
            </button>
          </div>
        </Modal>
      )}

      {modal === 'apoderado' && (
        <Modal title="Crear apoderado" onClose={closeModal}>
          {err && <div className="alert alert-red">{err}</div>}
          <label className="form-label">Nombre completo</label>
          <input className="form-input" placeholder="ej: María González" value={form.ap_name || ''} onChange={e => setF('ap_name', e.target.value)} />
          <label className="form-label">Nombre de usuario</label>
          <input className="form-input" placeholder="ej: mgonzalez (sin espacios)" value={form.ap_user || ''} onChange={e => setF('ap_user', e.target.value.toLowerCase().replace(/\s/g, ''))} />
          <label className="form-label">Contraseña inicial</label>
          <input className="form-input" placeholder="El apoderado deberá cambiarla al ingresar" value={form.ap_pass || ''} onChange={e => setF('ap_pass', e.target.value)} />
          <label className="form-label">Alumno(s) asociado(s)</label>
          <StudentPicker students={students} selected={form.ap_students || []} onChange={v => setF('ap_students', v)} />
          {!(form.ap_students || []).length && <div className="alert alert-amber" style={{ fontSize: 11 }}>Debes seleccionar al menos un alumno.</div>}
          <div className="modal-footer">
            <button className="btn btn-ghost" onClick={closeModal}>Cancelar</button>
            <button className="btn btn-primary" disabled={isPending || !form.ap_name || !form.ap_user || !form.ap_pass || !(form.ap_students || []).length} onClick={handleSaveApoderado}>
              {isPending ? 'Creando…' : 'Crear apoderado'}
            </button>
          </div>
        </Modal>
      )}
    </div>
  )
}

'@ | Out-File -FilePath 'src\components\TesoreraDashboard.tsx' -Encoding utf8

Write-Host 'Creando src\components\ApoderadoDashboard.tsx...'
@'
'use client'
// src/components/ApoderadoDashboard.tsx

import { useTransition } from 'react'
import { logoutAction } from '` @/actions/auth'
import type { AppUser, Student, Quota, Payment, Expense } from '` @/lib/supabase/types'

const clp   = (n: number) => `$${Math.round(n).toLocaleString('es-CL')}`
const dateF = (s?: string | null) => s
  ? new Date(s + 'T00:00:00').toLocaleDateString('es-CL', { day: '2-digit', month: 'short', year: 'numeric' })
  : '—'

const quotaParticipants = (q: Quota, students: Student[]) =>
  q.participant_ids ?? students.map(s => s.id)

const isParticipant = (q: Quota, sid: string, students: Student[]) =>
  quotaParticipants(q, students).includes(sid)

interface ApoderadoData {
  user:     AppUser
  students: Student[]
  quotas:   Quota[]
  payments: Payment[]
  expenses: Expense[]
}

export function ApoderadoDashboard({ data }: { data: ApoderadoData }) {
  const { user, students, quotas, payments, expenses } = data
  const [, startTransition] = useTransition()

  const totalIncome   = payments.reduce((s, p) => { const q = quotas.find(q => q.id === p.quota_id); return s + (q?.amount ?? 0) }, 0)
  const totalExpense  = expenses.reduce((s, e) => s + e.amount, 0)
  const balance       = totalIncome - totalExpense
  const totalExpected = quotas.reduce((s, q) => s + q.amount * quotaParticipants(q, students).length, 0)
  const globalPct     = totalExpected > 0 ? Math.round((totalIncome / totalExpected) * 100) : 0

  const hasPaid = (sid: string, qid: string) => payments.some(p => p.student_id === sid && p.quota_id === qid)

  return (
    <div>
      {/* TOPBAR */}
      <div className="topbar">
        <div>
          <div className="topbar-title">📋 Tesorería <span>Curso</span></div>
          <div className="topbar-sub">Vista Apoderado · {user.display_name}</div>
        </div>
        <div className="topbar-right">
          <span className="topbar-user">👤 {user.display_name}</span>
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => startTransition(() => logoutAction())}
          >
            Salir
          </button>
        </div>
      </div>

      <div className="content" style={{ maxWidth: 740 }}>

        {/* Balance general */}
        <div className="card mb-4">
          <div className="card-title">Balance general del curso</div>
          <div className="card-grid card-grid-3 mb-4">
            <div className="kpi kpi-indigo">
              <div className="kpi-label">Saldo actual</div>
              <div className="kpi-value" style={{ fontSize: 20 }}>{clp(balance)}</div>
            </div>
            <div className="kpi kpi-green">
              <div className="kpi-label">Recaudado</div>
              <div className="kpi-value" style={{ fontSize: 20 }}>{clp(totalIncome)}</div>
            </div>
            <div className="kpi kpi-red">
              <div className="kpi-label">Gastado</div>
              <div className="kpi-value" style={{ fontSize: 20 }}>{clp(totalExpense)}</div>
            </div>
          </div>
          <div className="row mb-3">
            <span className="fs-12 c-muted fw-700" style={{ textTransform: 'uppercase', letterSpacing: '0.06em' }}>
              Avance de recaudación del curso
            </span>
            <span className="fw-700 c-indigo fs-13">{globalPct}%</span>
          </div>
          <div className="progress-bar" style={{ height: 9 }}>
            <div className="progress-fill" style={{
              width: `${globalPct}%`,
              background: globalPct >= 80 ? 'var(--green)' : globalPct >= 50 ? 'var(--indigo)' : 'var(--amber)'
            }} />
          </div>
          <div className="row mt-3">
            <span className="fs-11 c-muted">Esperado: {clp(totalExpected)}</span>
            <span className="fs-11 c-muted">Por cobrar: <strong style={{ color: 'var(--red)' }}>{clp(totalExpected - totalIncome)}</strong></span>
          </div>
        </div>

        {/* Estado por cada hijo del apoderado */}
        {data.students.map(s => {
          const myPays     = payments.filter(p => p.student_id === s.id)
          const myQuotas   = quotas.filter(q => isParticipant(q, s.id, students))
          const myExpected = myQuotas.reduce((sum, q) => sum + q.amount, 0)
          const myPaid     = myPays.reduce((sum, p) => { const q = quotas.find(q => q.id === p.quota_id); return sum + (q?.amount ?? 0) }, 0)
          const allPaid    = myQuotas.every(q => hasPaid(s.id, q.id))

          return (
            <div key={s.id} className="card mb-4">
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
                <div className="card-title" style={{ marginBottom: 0 }}>📚 {s.name}</div>
                {allPaid && myQuotas.length > 0
                  ? <span className="badge badge-green">✓ Al día</span>
                  : <span className="badge badge-amber">{myQuotas.filter(q => !hasPaid(s.id, q.id)).length} pendiente(s)</span>
                }
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
                {quotas.map(q => {
                  const applies = isParticipant(q, s.id, students)
                  const paid    = hasPaid(s.id, q.id)
                  const pay     = myPays.find(p => p.quota_id === q.id)

                  if (!applies) return (
                    <div key={q.id} style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                      background: 'var(--gray-lt)', borderRadius: 9, padding: '11px 14px',
                      border: '1px solid var(--border)', opacity: 0.55
                    }}>
                      <span className="fw-700 fs-13" style={{ color: 'var(--muted)' }}>{q.name}</span>
                      <span className="badge badge-gray">No aplica</span>
                    </div>
                  )

                  return (
                    <div key={q.id} style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                      background: paid ? 'var(--green-lt)' : 'var(--red-lt)',
                      borderRadius: 9, padding: '11px 14px',
                      border: `1px solid ${paid ? '#bbf7d0' : '#fecaca'}`
                    }}>
                      <div>
                        <div style={{ display: 'flex', gap: 7, alignItems: 'center', marginBottom: 3 }}>
                          <span className="fw-700 fs-13">{q.name}</span>
                          <span className={`badge ${q.type === 'mensual' ? 'badge-indigo' : 'badge-blue'}`}>
                            {q.type === 'mensual' ? 'Mensual' : 'Especial'}
                          </span>
                        </div>
                        {paid && <div className="fs-12 c-muted">Pagado el {dateF(pay?.paid_at)}</div>}
                        {!paid && q.due_date && <div className="fs-12" style={{ color: 'var(--red)' }}>Vence: {dateF(q.due_date)}</div>}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span className="fw-700 fs-13" style={{ color: paid ? 'var(--green)' : 'var(--red)' }}>{clp(q.amount)}</span>
                        <span className={`badge ${paid ? 'badge-green' : 'badge-red'}`}>{paid ? '✓ Pagado' : 'Pendiente'}</span>
                      </div>
                    </div>
                  )
                })}
              </div>

              <div style={{ background: 'var(--bg)', borderRadius: 9, padding: '12px 14px' }}>
                <div className="row mb-3">
                  <span className="fs-13 c-muted">Total pagado</span>
                  <span className="fw-700 c-green" style={{ fontFamily: "'Fraunces',serif", fontSize: 16 }}>{clp(myPaid)}</span>
                </div>
                <div className="row">
                  <span className="fs-13 c-muted">Pendiente (cuotas que te aplican)</span>
                  <span className="fw-700" style={{ fontFamily: "'Fraunces',serif", fontSize: 16, color: myExpected - myPaid > 0 ? 'var(--red)' : 'var(--green)' }}>
                    {clp(myExpected - myPaid)}
                  </span>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

'@ | Out-File -FilePath 'src\components\ApoderadoDashboard.tsx' -Encoding utf8

Write-Host 'Creando src\app\page.tsx...'
@'
import { redirect } from "next/navigation"
export default function Home() { redirect("/login") }

'@ | Out-File -FilePath 'src\app\page.tsx' -Encoding utf8

Write-Host 'Listo! Ahora crea el archivo .env.local' -ForegroundColor Green