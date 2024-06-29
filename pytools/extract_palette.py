import argparse
from PIL import Image

def extract_palette(image_path):
    # Apri l'immagine
    image = Image.open(image_path)
    
    # Verifica se l'immagine è in modalità 'P' (palette)
    if image.mode != 'P':
        raise ValueError("L'immagine non è in modalità 'P' (palette)")

    # Ottieni la palette dell'immagine
    palette = image.getpalette()
    
    # Ottieni i colori unici usati nell'immagine
    colors = image.getcolors()
    
    # Converti la palette in una lista di tuple RGB
    palette_rgb = [palette[i:i+3] for i in range(0, len(palette), 3)]
    
    # Funzione per convertire un valore RGB da 8 bit a 4 bit
    def to_4bit(rgb):
        return tuple(value // 16 for value in rgb)

    # Funzione per convertire un valore RGB a 4 bit in formato esadecimale
    def to_hex(rgb):
        return '{:01X}{:01X}{:01X}'.format(*rgb)
    
    # Estrai i colori usati nell'immagine, converti a 4 bit e poi a esadecimale
    used_colors_hex = [to_hex(to_4bit(palette_rgb[index])) for count, index in colors]
    
    return used_colors_hex

def save_raw_image(image_path, output_path):
    # Apri l'immagine
    image = Image.open(image_path)
    
    # Verifica se l'immagine è in modalità 'P' (palette)
    if image.mode != 'P':
        raise ValueError("L'immagine non è in modalità 'P' (palette)")

    # Estrai i dati dei pixel
    pixel_data = image.tobytes()

def main():
    # Configura l'analizzatore degli argomenti
    parser = argparse.ArgumentParser(description='Estrai i valori RGB a 4 bit in formato esadecimale da un\'immagine PNG indicizzata e salva il contenuto raw dell\'immagine.')
    parser.add_argument('image_path', type=str, help='Il percorso dell\'immagine PNG')
    
    # Analizza gli argomenti della riga di comando
    args = parser.parse_args()
    
    # Estrai i colori dall'immagine
    colors = extract_palette(args.image_path)
    
    # Stampa i colori
    colorcode = 384



    for i, color in enumerate(colors):
        #colorcode = hex_sum(colorcode,colorincrement)
        print(f"dc.w ${hex(colorcode)[2:]},${color} ; Color {i}")
        colorcode = colorcode + 2

if __name__ == "__main__":
    main()
