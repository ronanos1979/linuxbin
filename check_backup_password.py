import sys
from iphone_backup_decrypt import EncryptedBackup

password = sys.argv[1]
backup_path = '/Users/ronanosullivan/Library/Application Support/MobileSync/Backup/00008030-0001391E0C40802E-20200816-210646'

print(f"Testing: {password}")
backup = EncryptedBackup(backup_directory=backup_path, passphrase=password)
try:
    backup.extract_file(relative_path='Library/SMS/sms.db', output_filename='/tmp/test_sms.db')
    print('✓ Password correct!')
except Exception as e:
    print(f'✗ Wrong password or error: {e}')
EOF
