#!/bin/bash

# Nama file output
OUTPUT_FILE="final_yara_rules.yar"

# Folder target
TARGET_DIRS=("dev" "third-party")

if [ -f "$OUTPUT_FILE" ]; then
    echo "[*] Menghapus $OUTPUT_FILE versi lama..."
    rm "$OUTPUT_FILE"
fi

echo "// ===================================================" > "$OUTPUT_FILE"
echo "// FINAL YARA RULES (CONCATENATED)" >> "$OUTPUT_FILE"
echo "// ===================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "[*] Mengumpulkan dan membersihkan duplikasi 'import' modul..."
# Menambahkan ! -name "*index*.yar" untuk membuang file daftar isi
find "${TARGET_DIRS[@]}" -type f -name "*.yar" ! -name "*index*.yar" -exec grep -h "^import " {} + | tr -d '\r' | sort | uniq >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"

echo "[*] Menggabungkan seluruh isi rules dari direktori dev/ dan third-party/..."
find "${TARGET_DIRS[@]}" -type f -name "*.yar" ! -name "*index*.yar" | sort | while read -r file; do
    echo "// --- Source: $file ---" >> "$OUTPUT_FILE"
    
    # Mengambil isi rule, tapi MENGABAIKAN baris yang berawalan 'import' ATAU 'include'
    grep -vE "^[[:space:]]*import " "$file" | grep -vE "^[[:space:]]*include " >> "$OUTPUT_FILE"
    
    echo "" >> "$OUTPUT_FILE"
done

# Menghitung total file yang digabungkan
TOTAL_FILES=$(find "${TARGET_DIRS[@]}" -type f -name "*.yar" ! -name "*index*.yar" | wc -l)

echo "[+] Selesai!"
echo "[+] File $OUTPUT_FILE berhasil dibuat."