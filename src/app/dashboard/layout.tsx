// src/app/dashboard/layout.tsx
// Verifica que el usuario sea tesorera, si no redirige

import { redirect } from 'next/navigation'
import { getCurrentAppUser } from '@/actions/auth'

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

