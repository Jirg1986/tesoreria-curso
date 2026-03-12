// src/app/change-password/page.tsx
'use client'

import { useState, useTransition } from 'react'
import { changePasswordAction } from '@/actions/auth'

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

