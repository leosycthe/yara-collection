#!/bin/bash

# ===================================================
# YARA RULES BUILDER & COMPILER v2.0
# ===================================================

OUTPUT_FILE="final_yara_rules.yar"
COMPILED_FILE="final_yara_rules.yarc"

# sesuaikan pathnya ini untuk endpoints windows yang dipakai daily
TARGET_DIRS=(
    "dev" # [WAJIB] Rule buatan internal tim
    "third-party/signature-base" # [WAJIB] Core intel & high confidence rules
    "third-party/reversinglabs" # [WAJIB] Malware family spesifik
    # --- PROFIL SERVER LINTAS PLATFORM ---
    "third-party/yara-rules/webshells" # Krusial untuk proteksi Web Server
    "third-party/yara-rules/malware" # Botnet dan trojan umum
    "third-party/yara-rules/cve_rules" # Deteksi eksploitasi kerentanan
    "third-party/yara-rules/exploit_kits" # Deteksi tools peretasan
    # --- khusus endpoint laptop karayawan dan email server ---
    "third-party/yara-rules/maldocs" #PROFIL ENDPOINT WINDOWS (KARYAWAN)
    "third-party/yara-rules/email" #PROFIL ENDPOINT WINDOWS (KARYAWAN)
)

BLACKLIST=()

if [ -f "$OUTPUT_FILE" ]; then
    echo "[*] Menghapus $OUTPUT_FILE versi lama..."
    rm "$OUTPUT_FILE"
fi
if [ -f "$COMPILED_FILE" ]; then
    rm "$COMPILED_FILE"
fi

echo "// ===================================================" > "$OUTPUT_FILE"
echo "// FINAL YARA RULES (CONCATENATED)" >> "$OUTPUT_FILE"
echo "// ===================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"


# FASE 0: SMART DEDUPLICATION (Mengekstrak Rule Name)
echo "[*] FASE 0: Membangun indeks Identifier dari Repositori Utama..."
INDEX_FILE="/tmp/yara_master_index.txt"
grep -rhoE "^rule [a-zA-Z0-9_]+" dev/ third-party/signature-base/ 2>/dev/null | awk '{print $2}' | sort | uniq > "$INDEX_FILE"
TOTAL_MASTER_RULES=$(wc -l < "$INDEX_FILE")
echo "    -> Menemukan $TOTAL_MASTER_RULES identifier utama (dilindungi dari duplikasi)."

# FASE 1: MEMBERSIHKAN IMPORTS
echo "[*] FASE 1: Mengumpulkan dan membersihkan duplikasi 'import' modul..."
while read -r file; do
    grep -h "^import " "$file" | tr -d '\r'
done < <(find "${TARGET_DIRS[@]}" -type f \( -name "*.yar" -o -name "*.yara" \) ! -name "*index*.yar" ! -name "*index*.yara" 2>/dev/null | sort) | sort | uniq >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"

# FASE 2: PENGGABUNGAN DENGAN FILTER DUPLIKAT
echo "[*] FASE 2: Menggabungkan seluruh isi rules (Mengeksekusi Smart Filter)..."
TOTAL_FILES=0
SKIPPED_FILES=0

# Menggunakan Process Substitution untuk menghindari hilangnya nilai variabel (Subshell Trap)
while read -r file; do
    
    BASENAME=$(basename "$file")
    if [[ " ${BLACKLIST[@]} " =~ " ${BASENAME} " ]]; then
        echo "    [SKIPPED] File ada di Blacklist: $BASENAME"
        ((SKIPPED_FILES++))
        continue
    fi

    if [[ "$file" != *"dev/"* ]] && [[ "$file" != *"signature-base/"* ]]; then
        RULE_NAMES=$(grep -hoE "^rule [a-zA-Z0-9_]+" "$file" | awk '{print $2}')
        CONFLICT=false
        
        for rn in $RULE_NAMES; do
            if grep -qx "$rn" "$INDEX_FILE"; then
                echo "    [CONFLICT] Menolak $BASENAME (Rule '$rn' sudah ada di Signature-Base)."
                CONFLICT=true
                break
            fi
        done
        
        if [ "$CONFLICT" = true ]; then
            ((SKIPPED_FILES++))
            continue
        fi
    fi

    echo "// --- Source: $file ---" >> "$OUTPUT_FILE"
    grep -vE "^[[:space:]]*import " "$file" | grep -vE "^[[:space:]]*include " >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    ((TOTAL_FILES++))
    
done < <(find "${TARGET_DIRS[@]}" -type f \( -name "*.yar" -o -name "*.yara" \) ! -name "*index*.yar" ! -name "*index*.yara" 2>/dev/null | sort)

rm -f "$INDEX_FILE"

echo "[+] PENGGABUNGAN SELESAI!"
echo "    -> Total File Digabungkan : $TOTAL_FILES"
echo "    -> Total File Diabaikan   : $SKIPPED_FILES (karena duplikat)"
echo "---------------------------------------------------"
echo "[*] Memulai Validasi & Kompilasi menggunakan yarac..."

if command -v yarac &> /dev/null; then
    # Menggunakan flag -d untuk mendeklarasikan variabel eksternal YARA agar tidak error
    yarac -d filename="" -d filepath="" -d extension="" -d filetype="" -d owner="" "$OUTPUT_FILE" "$COMPILED_FILE"
    
    if [ $? -eq 0 ]; then
        echo "[✅] SUKSES! Rules valid dan dikompilasi menjadi: $COMPILED_FILE"
        echo "[✅] File biner ini siap dikirim ke endpoint Wazuh!"
    else
        echo "[❌] GAGAL! Terdapat error syntax saat kompilasi."
    fi
else
    echo "[⚠️] PERINGATAN: 'yarac' tidak terinstal di mesin ini."
fi
