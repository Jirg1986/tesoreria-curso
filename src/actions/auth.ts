'use server'
// src/actions/auth.ts

import { redirect } from 'next/navigation'
import { createClient, createServiceClient } from '@/lib/supabase/server'

// â”€â”€ Construir email ficticio interno â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// El usuario nunca ve esto. Formato: username@curso-COURSEID.internal
function buildFakeEmail(username: string, courseId: string) {
  return `${username}@curso-${courseId}.internal`
}

// â”€â”€ LOGIN â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export async function loginAction(formData: FormData) {
  const username = formData.get('username') as string
  const password = formData.get('password') as string

  if (!username || !password) {
    return { error: 'Ingresa usuario y contraseÃ±a.' }
  }

  const supabase = await createClient()

  // 1. Buscar el app_user por username para obtener course_id
  //    Necesitamos el service client porque aÃºn no hay sesiÃ³n
  const service = createServiceClient()
  const { data: appUser, error: userError } = await service
    .from('app_users')
    .select('*, course_id')
    .eq('username', username)
    .single()

  if (userError || !appUser) {
    return { error: 'Usuario o contraseÃ±a incorrectos.' }
  }

  // 2. Construir email ficticio y autenticar
  const email = buildFakeEmail(username, appUser.course_id)
  const { error: authError } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (authError) {
    return { error: 'Usuario o contraseÃ±a incorrectos.' }
  }

  // 3. Redirigir segÃºn rol
  if (appUser.must_change_password) {
    redirect('/change-password')
  }

  if (appUser.role === 'tesorera') {
    redirect('/dashboard')
  } else {
    redirect('/apoderado')
  }
}

// â”€â”€ LOGOUT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export async function logoutAction() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect('/login')
}

// â”€â”€ CAMBIAR CONTRASEÃ‘A â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export async function changePasswordAction(formData: FormData) {
  const password    = formData.get('password') as string
  const confirmPass = formData.get('confirm') as string

  if (!password || password.length < 4) {
    return { error: 'La contraseÃ±a debe tener al menos 4 caracteres.' }
  }
  if (password !== confirmPass) {
    return { error: 'Las contraseÃ±as no coinciden.' }
  }

  const supabase = await createClient()

  // Actualizar clave en Supabase Auth
  const { error: authError } = await supabase.auth.updateUser({ password })
  if (authError) return { error: 'Error al cambiar la contraseÃ±a.' }

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

// â”€â”€ OBTENER USUARIO ACTUAL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€ CREAR APODERADO (solo tesorera) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€ RESET CLAVE APODERADO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€ ELIMINAR APODERADO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

