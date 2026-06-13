import 'package:flutter/foundation.dart';

/// Registers all custom proprietary licenses for the AI Recruiter software
/// and assets. These will appear beautifully structured under the built-in
/// license viewer in the "About" dialog.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['ai_recruiter_software'],
      '''
AI RECRUITER END-USER LICENSE AGREEMENT (EULA)
Copyright (c) 2026 AI Recruiter. All Rights Reserved.

1. LICENSE GRANT
AI Recruiter grants you a non-exclusive, non-transferable, revocable license to 
use this software solely for internal business operations and personal hiring 
management, subject to the terms of this Agreement.

2. RESTRICTIONS
You agree not to, and you will not permit others to:
- License, sell, rent, lease, assign, distribute, host, or outsource the Software.
- Modify, make derivative works of, disassemble, decrypt, reverse compile, or 
  reverse engineer any part of the Software.
- Remove, alter, or obscure any proprietary notice (including copyright or 
  trademark notices) of AI Recruiter or its affiliates.

3. INTELLECTUAL PROPERTY
All intellectual property rights, including copyrights, patents, trademarks, 
and trade secrets in the Software, are and shall remain the sole and exclusive 
property of AI Recruiter.

4. LIMITATION OF LIABILITY
The Software is provided "AS IS" without warranty of any kind. In no event shall 
AI Recruiter be liable for any special, incidental, indirect, or consequential 
damages whatsoever arising out of the use or inability to use the Software.
''',
    );
    
    yield const LicenseEntryWithLineBreaks(
      ['ai_recruiter_brand_assets'],
      '''
AI RECRUITER PROPRIETARY ASSETS LICENSE
Copyright (c) 2026 AI Recruiter. All Rights Reserved.

This license governs the use of all proprietary design assets, illustrations, 
animations, glassmorphic UI card designs, premium mesh gradient backgrounds, 
vector graphics, and brand logos embedded within the AI Recruiter application.

1. USAGE TERMS
All visual assets, themes, and aesthetic brand identities are proprietary 
intellectual property. These assets may not be extracted, copied, redistributed, 
or repackaged in external products or derivative works without prior written 
consent from AI Recruiter.
''',
    );
  });
}
