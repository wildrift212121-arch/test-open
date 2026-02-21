MouseMove($startX, $startY, 1)         ; Переместить курсор в начальную точку
MouseDown("left")                      ; Нажать ЛКМ
Sleep(120)
For $i = 1 To 20
    MouseMove($startX + $i * 10, $startY, 1)
    Sleep(35)
Next
MouseUp("left")       