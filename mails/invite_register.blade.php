<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Complete Registration</title>
</head>
<body style="margin:0;padding:0;background:#0b1220;font-family:Arial,Helvetica,sans-serif;">
    <div style="width:100%;padding:32px 12px;box-sizing:border-box;">
        <div style="max-width:720px;margin:0 auto;">
            <div style="text-align:center;margin-bottom:18px;">
                <a href="{{ config('app.url') }}" style="display:inline-block;text-decoration:none;">
                    <img src="{{ asset('images/logo/wh_logo.png') }}" alt="Weather Hooligan logo"
                         style="height:56px;width:auto;display:block;margin:0 auto;">
                </a>
                <div style="margin-top:10px;font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#9ad7ff;">
                    Weather Hooligan
                </div>
            </div>

            <div style="background:#ffffff;border-radius:18px;padding:28px;box-shadow:0 12px 30px rgba(0,0,0,.25);">
                <h1 style="margin:0 0 10px 0;font-size:22px;line-height:1.3;color:#0f172a;">
                    Hi {{ $name }} {{ $surname }} 🌤️
                </h1>

                <p style="margin:0 0 16px 0;font-size:14px;line-height:1.65;color:#1f2937;">
                    Click the button below to complete your registration for Weather Hooligan.
                </p>

                <a href="{{ $link }}"
                   style="display:inline-block;padding:12px 16px;background:#38bdf8;color:#0b1220;text-decoration:none;font-weight:700;border-radius:10px;">
                    Complete Registration
                </a>

                <p style="margin:12px 0 0 0;font-size:12px;color:#6b7280;">
                    This link expires: {{ $expiresAt }}<br>
                    If you did not request this, you can ignore this email.
                </p>
            </div>
        </div>
    </div>
</body>
</html>
