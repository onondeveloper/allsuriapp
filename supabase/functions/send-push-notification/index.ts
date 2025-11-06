// Supabase Edge Function: FCM 푸시 알림 전송
// Deploy: supabase functions deploy send-push-notification

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!

serve(async (req) => {
  try {
    const { userId, title, body, data } = await req.json()

    if (!userId || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'userId, title, body are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Supabase 클라이언트 생성
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // FCM 토큰 조회
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('fcm_token')
      .eq('id', userId)
      .single()

    if (userError || !user || !user.fcm_token) {
      console.log(`No FCM token found for user: ${userId}`)
      return new Response(
        JSON.stringify({ success: false, message: 'No FCM token' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // FCM API 호출
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${FCM_SERVER_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: user.fcm_token,
        notification: {
          title,
          body,
          sound: 'default',
          badge: '1',
        },
        data: data || {},
        priority: 'high',
        content_available: true,
      }),
    })

    const fcmResult = await fcmResponse.json()

    if (!fcmResponse.ok) {
      console.error('FCM send failed:', fcmResult)
      return new Response(
        JSON.stringify({ success: false, error: fcmResult }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Push notification sent to user ${userId}`)

    return new Response(
      JSON.stringify({ success: true, result: fcmResult }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

