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
          TesorerÃ­a <em style={{ color: '#a5b4fc' }}>Curso</em>
        </div>
        <div style={{ color: '#6b7280', fontSize: 13, marginBottom: 32 }}>
          Ingresa con tu usuario y contraseÃ±a
        </div>

        {error && (
          <div style={{ background: 'rgba(220,38,38,0.15)', border: '1px solid rgba(220,38,38,0.3)', borderRadius: 8, padding: '10px 12px', color: '#fca5a5', fontSize: 12, fontWeight: 600, marginBottom: 16 }}>
            âš ï¸ {error}
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
            ContraseÃ±a
          </label>
          <input
            type="password"
            style={{ width: '100%', padding: '11px 14px', border: '1.5px solid rgba(255,255,255,0.1)', borderRadius: 9, fontSize: 14, background: 'rgba(255,255,255,0.06)', color: '#fff', marginBottom: 24, transition: 'border 0.15s' }}
            value={form.password}
            onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
            placeholder="â€¢â€¢â€¢â€¢â€¢â€¢â€¢â€¢"
            autoComplete="current-password"
          />

          <button
            type="submit"
            disabled={isPending}
            style={{ width: '100%', padding: 12, border: 'none', borderRadius: 9, background: isPending ? '#4338ca' : '#5b4df5', color: '#fff', fontFamily: "'Instrument Sans', sans-serif", fontWeight: 700, fontSize: 14, cursor: isPending ? 'wait' : 'pointer' }}
          >
            {isPending ? 'Ingresandoâ€¦' : 'Ingresar â†’'}
          </button>
        </form>
      </div>
    </div>
  )
}

