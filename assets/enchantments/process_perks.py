import re, os

# 1. Читаем listE.md (формат "КЛЮЧ - Название")
listE_keys = set()
if os.path.exists("listE.md"):
    with open("listE.md", "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or "-" not in line:
                continue
            parts = line.split("-", 1)
            raw_key = parts[0].strip().strip("[]").upper()
            listE_keys.add(raw_key)

# 2. Читаем lsl.md и разбираем блоки
if not os.path.exists("lsl.md"):
    print("[!] Ошибка: файл lsl.md не найден!")
    exit(1)

with open("lsl.md", "r", encoding="utf-8") as f:
    content = f.read()

# Разбиваем по блокам [key]
raw_blocks = re.split(r'\n(?=\[[a-zA-Z0-9_]+\])', content)

outE_blocks = []

for block in raw_blocks:
    block = block.strip()
    if not block:
        continue
    
    # Извлекаем ключ и ID
    key_match = re.match(r'^\[([a-zA-Z0-9_]+)\]', block)
    id_match = re.search(r'id\s*=\s*["\']([^"\']+)["\']', block)
    
    if key_match:
        key = key_match.group(1)
        perk_id = id_match.group(1).upper() if id_match else key.upper()
        
        # Если этого ID/ключа НЕТ в listE.md, заносим в outE
        if perk_id not in listE_keys:
            outE_blocks.append(block)

# 3. Записываем результат в outE.md
with open("outE.md", "w", encoding="utf-8") as f:
    f.write("\n\n".join(outE_blocks) + "\n")

print(f"[+] Всего блоков в lsl.md: {len(raw_blocks)}")
print(f"[+] Найдено и выгружено в outE.md (отсутствуют в listE.md): {len(outE_blocks)}")
