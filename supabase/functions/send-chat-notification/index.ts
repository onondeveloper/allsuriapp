import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS preflight request 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 요청 본문 파싱
    const { recipientUserId, message, chatRoomId, senderName } = await req.json()
    
    if (!recipientUserId || !message || !chatRoomId) {
      throw new Error('필수 파라미터가 누락되었습니다.')
    }

    // Supabase 클라이언트 생성
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 수신자의 FCM 토큰 가져오기
    const { data: userProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('fcm_token')
      .eq('userid', recipientUserId)
      .single()

    if (profileError || !userProfile?.fcm_token) {
      console.log('FCM 토큰을 찾을 수 없음:', recipientUserId)
      return new Response(
        JSON.stringify({ success: false, message: 'FCM 토큰을 찾을 수 없습니다.' }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404 
        }
      )
    }

    // FCM 서버 키 (환경 변수에서 가져오기)
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      throw new Error('FCM 서버 키가 설정되지 않았습니다.')
    }

    // FCM 메시지 전송
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${fcmServerKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: userProfile.fcm_token,
        notification: {
          title: `${senderName || '사용자'}님의 메시지`,
          body: message.length > 50 ? message.substring(0, 50) + '...' : message,
          sound: 'default',
          badge: '1',
        },
        data: {
          type: 'chat_message',
          chatRoomId: chatRoomId,
          message: message,
          senderUserId: recipientUserId,
          timestamp: new Date().toISOString(),
        },
        priority: 'high',
        android: {
          priority: 'high',
          notification: {
            channel_id: 'chat_notifications',
            priority: 'high',
            default_sound: true,
            default_vibrate_timings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
              category: 'chat_message',
            },
          },
        },
      }),
    })

    if (!fcmResponse.ok) {
      const errorText = await fcmResponse.text()
      console.error('FCM 전송 실패:', fcmResponse.status, errorText)
      throw new Error(`FCM 전송 실패: ${fcmResponse.status}`)
    }

    const fcmResult = await fcmResponse.json()
    console.log('FCM 전송 성공:', fcmResult)

    // 알림 기록을 Supabase에 저장 (선택사항)
    try {
      await supabase
        .from('notifications')
        .insert({
          userid: recipientUserId,
          title: `${senderName || '사용자'}님의 메시지`,
          body: message,
          type: 'chat_message',
          chatroomid: chatRoomId,
          isread: false,
          createdat: new Date().toISOString(),
        })
    } catch (notificationError) {
      console.log('알림 기록 저장 실패 (무시됨):', notificationError)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: '알림 전송 완료',
        fcmResult 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error('에러 발생:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: error.message || '알 수 없는 오류가 발생했습니다.' 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 
      }
    )
  }
})
