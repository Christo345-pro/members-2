<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Welcome to Weather Hooligan</title>
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
                    Weather Hooligan
                </div>
            </div>

            {{-- Hero --}}
            <div style="background:linear-gradient(135deg,#0f172a,#0b3b5a);border-radius:18px;padding:24px;color:#eaf6ff;border:1px solid rgba(255,255,255,.08);">
                <h1 style="margin:0 0 8px 0;font-size:22px;line-height:1.3;">
                    A warm weatherly welcome to you, {{ $name }}@if(!empty($surname)) {{ $surname }}@endif
                </h1>
                <p style="margin:0;font-size:13px;opacity:.9;">
                    Signed up on {{ $date }}. We’re glad you’re here.
                </p>
            </div>

            {{-- Card --}}
            <div style="background:#ffffff;border-radius:18px;padding:28px;margin-top:16px;box-shadow:0 12px 30px rgba(0,0,0,.25);">

                <p style="margin:0 0 16px 0;font-size:14px;line-height:1.65;color:#1f2937;">
                    We want to welcome you and thank you for using our app. The installation file(s) for your chosen
                    product(s) will be sent by email.
                </p>

                <div style="margin:18px 0;padding:16px;background:#f3f9ff;border:1px solid #d5ecff;border-radius:14px;">
                    <div style="font-size:13px;font-weight:700;color:#0b2a42;margin-bottom:10px;text-transform:uppercase;letter-spacing:1.5px;">
                        Selected products
                    </div>

                    @if(!empty($appAndroid))
                        <div style="font-size:13px;color:#0b2a42;margin-bottom:6px;">
                            Android App
                        </div>
                    @endif

                    @if(!empty($appWindows))
                        <div style="font-size:13px;color:#0b2a42;margin-bottom:6px;">
                            Windows App
                        </div>
                    @endif

                    @if(!empty($appWeb))
                        <div style="font-size:13px;color:#0b2a42;margin-bottom:6px;">
                            Web App
                        </div>
                    @endif

                    @if(empty($appAndroid) && empty($appWindows) && empty($appWeb))
                        <div style="font-size:13px;color:#0b2a42;">
                            Your selection will be confirmed by our team.
                        </div>
                    @endif
                </div>

                <div style="margin:18px 0;padding:14px 16px;background:#fff7ed;border:1px solid #fed7aa;border-radius:12px;">
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#7c2d12;">
                        Keep notifications enabled so you don’t miss important storm path updates.
                    </p>
                </div>

                <div style="margin:18px 0;padding:16px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;">
                    <p style="margin:0 0 10px 0;font-size:14px;line-height:1.6;color:#1f2a37;">
                        Need help? Reach us on WhatsApp or email:
                    </p>
                    <a href="{{ $whatsappUrl }}"
                       style="display:inline-block;margin-right:8px;padding:10px 14px;background:#16a34a;color:#ffffff;text-decoration:none;border-radius:10px;font-weight:700;">
                        WhatsApp Support
                    </a>
                    <a href="mailto:{{ $supportEmail }}"
                       style="display:inline-block;padding:10px 14px;background:#111827;color:#ffffff;text-decoration:none;border-radius:10px;font-weight:700;">
                        Email Support
                    </a>
                </div>

                <p style="margin:0 0 14px 0;font-size:14px;line-height:1.65;color:#1f2937;">
                    We also have an online contact form:
                    <a href="{{ $contactFormUrl }}" style="color:#0b63f6;text-decoration:underline;">
                        {{ $contactFormUrl }}
                    </a>
                </p>

                <hr style="border:none;border-top:1px solid #eef2f7;margin:18px 0;">

                <p style="margin:0;font-size:14px;line-height:1.65;color:#111;">
                    Yours truly with a warm sunny welcome from the<br>
                    <strong>WEATHER HOOLIGAN APP TEAM</strong>
                </p>

                {{-- Footer tiny --}}
                <p style="margin:18px 0 0 0;font-size:12px;line-height:1.6;color:#6b7280;">
                    You’re receiving this email because you signed up for the Weather Hooligan App.
                </p>

            </div>
        </div>
    </div>
</body>
</html>
