
import os

dirs = os.listdir(os.getcwd())

for i in dirs:
    if not os.path.isdir(i):
        continue 
    os.chdir(i) 
    files = os.listdir(os.getcwd())
    for file in files:
        if os.path.splitext(file)[1] == ".md":
            text = open(file, encoding="utf-8").read()
            text = text.replace("../images/", "")
            # text = text.replace(".png)", ".png?imageslim)")
            # text = text.replace("### #", "### ")
            open(file, "w", encoding="utf-8").write(text)
    os.chdir("..")