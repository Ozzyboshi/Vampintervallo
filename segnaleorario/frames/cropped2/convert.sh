#!/bin/bash

# Controlla se sono stati passati due file come argomenti
if [ $# -ne 2 ]; then
    echo "Uso: $0 <file di input> <file di output>"
    exit 1
fi

input_file="$1"
output_file="$2"

# Verifica che il file di input esista
if [ ! -f "$input_file" ]; then
    echo "Errore: Il file di input '$input_file' non esiste."
    exit 1
fi

# Inizia con un file di output vuoto
> "$output_file"

# Leggi il file di input riga per riga
while IFS= read -r line; do
    # Estrai la parte del valore RGB e il commento
    rgb_hex=$(echo "$line" | awk '{print $2}')
    comment=$(echo "$line" | awk -F ';' '{print $2}')

    # Rimuovi il prefisso "$" e convertilo in minuscolo
    rgb_hex=${rgb_hex:1}

    # Estrai i singoli componenti R, G e B
    r=${rgb_hex:0:2}
    g=${rgb_hex:2:2}
    b=${rgb_hex:4:2}

    # Converte ogni componente da esadecimale a decimale
    r_dec=$((0x$r))
    g_dec=$((0x$g))
    b_dec=$((0x$b))

    # Prendi i 4 bit più bassi di ogni componente
    r_12bit=$((r_dec >> 0))
    g_12bit=$((g_dec >> 0))
    b_12bit=$((b_dec >> 0))

    # Converti ogni componente in esadecimale a 1 cifra
    r_12bit_hex=$(printf "%x" $r_12bit)
    g_12bit_hex=$(printf "%x" $g_12bit)
    b_12bit_hex=$(printf "%x" $b_12bit)
         echo "r prima vale $r_dec" 
        echo "r vale $r_12bit"


    # Crea il colore a 12 bit
    color_12bit="0${r_12bit_hex}${g_12bit_hex}${b_12bit_hex}"

    # Aggiungi il registro hardware dal commento
    hardware_reg=$(echo "$comment" | awk '{print $NF}')

    # Genera la riga di output e la scrive nel file di output
    echo "    dc.w $hardware_reg,\$$color_12bit ;$comment" >> "$output_file"

done < "$input_file"

echo "Conversione completata. Il risultato è stato salvato in '$output_file'."
