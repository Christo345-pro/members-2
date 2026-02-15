<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Weather Hooligan App Official</title>
</head>

<body style="margin:0;padding:0;background:#0b1220;font-family:Arial,Helvetica,sans-serif;">
<div style="width:100%;padding:32px 12px;box-sizing:border-box;">
    <div style="max-width:720px;margin:0 auto;">

        {{-- Header --}}
        <div style="text-align:center;margin-bottom:18px;">
            <a href="{{ config('app.url') }}" style="display:inline-block;text-decoration:none;">
                <img
                    src="{{ asset('images/logo/wh_logo.png') }}"
                    alt="Weather Hooligan logo"
                    style="height:56px;width:auto;display:block;margin:0 auto;"
                >
            </a>
            <div style="margin-top:10px;font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#9ad7ff;">
                Weather Hooligan App Division (Pty) Ltd
            </div>
        </div>

        {{-- Company Info --}}
        <div style="background:linear-gradient(135deg,#0f172a,#0b3b5a);
                    border-radius:18px;
                    padding:24px;
                    color:#eaf6ff;
                    border:1px solid rgba(255,255,255,.08);
                    font-size:12px;
                    line-height:1.6;">
            Registration nr: 2026/048301/07<br>
            Phone: 074 234 6350<br>
            WhatsApp: 074 234 6350<br>
            Email: info@weather-hooligan.co.za<br>
            Web: https://www.weather-hooligan.co.za
        </div>

        {{-- White Content Card --}}
        <div style="background:#ffffff;
                    border-radius:18px;
                    padding:28px;
                    margin-top:16px;
                    box-shadow:0 12px 30px rgba(0,0,0,.25);">

            {{-- Date --}}
            <div style="text-align:right;font-size:12px;color:#6b7280;margin-bottom:12px;">
                {{ now()->locale('af')->translatedFormat('d F Y') }}
            </div>

            {{-- Greeting --}}
            <p style="margin:0 0 16px 0;font-size:14px;color:#1f2937;">
                Dear {{ $name }}@if(!empty($surname)) {{ $surname }}@endif,
            </p>

            {{-- Email Content --}}
            <div style="font-size:14px;line-height:1.7;color:#1f2937;">
                {!! nl2br(e($content)) !!}
            </div>

            {{-- Signature --}}
            <p style="margin-top:28px;font-size:14px;color:#1f2937;">
                Kind regards,<br><br>
                <strong>The Weather Hooligan Team</strong>
            </p>
        </div>

        {{-- Footer (OUTSIDE white card) --}}
        <div style="margin-top:40px;text-align:center;">
            <p style="margin:0;font-size:12px;line-height:1.6;color:#9ca3af;">
                Directors: CAJ Dreyer, JJ Vorster
            </p>

            <p style="margin:12px 0 0 0;font-size:12px;line-height:1.6;color:#9ca3af;">
                This is an official email. If this email is not intended for you,
                please ignore and delete it.
            </p>
        </div>

    </div>
</div>
</body>
</html>
