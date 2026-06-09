import "hash"

rule MalwareBazaar_Test_Sample {
    meta:
        description = "Mendeteksi spesifik sampel dari MalwareBazaar untuk pengujian"
        author = "SOC Analyst Lab"
        date = "2026-06-07"
    condition:
        // Mengecek apakah hash SHA256 file sama
        hash.sha256(0, filesize) == "7de2c1bf58bce09eecc70476747d88a26163c3d6bb1d85235c24a558d1f16754"
}
