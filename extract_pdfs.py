
import os
from pypdf import PdfReader

def extract_text_from_pdfs(directory, filenames, output_file):
    with open(output_file, 'w', encoding='utf-8') as out_f:
        for filename in filenames:
            path = os.path.join(directory, filename)
            out_f.write(f"--- START OF {filename} ---\n")
            try:
                reader = PdfReader(path)
                text = ""
                for page in reader.pages:
                    text += page.extract_text() + "\n"
                out_f.write(text)
            except Exception as e:
                out_f.write(f"Error reading file: {e}\n")
            out_f.write(f"\n--- END OF {filename} ---\n\n")

if __name__ == "__main__":
    target_dir = "c:/Users/integ/Documents/MiDespensa"
    target_files = [
        "3 Plan de Desarrollo de Aplicaciones por Fases.pdf",
        "1 Diseño de Super App de Delivery Híbrida.pdf",
        "2 Arquitectura Sistema Entrega Híbrido.pdf",
        "4 Inventario de Pantallas MVP.pdf",
        "6 Reglas de Negocio y Estructura de Proyecto.pdf"
    ]
    
    extract_text_from_pdfs(target_dir, target_files, "extracted_content.txt")
    print("Done extracting text to extracted_content.txt")
