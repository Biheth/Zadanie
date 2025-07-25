Option Explicit

' Проверка аргументов
If WScript.Arguments.Count < 4 Then
    WriteProgress "ERROR: Недостаточно аргументов"
    WScript.Quit 1
End If

' Получение параметров
Dim xlsPath, docxPath, selectedDate, progressFile
xlsPath = WScript.Arguments(0)
docxPath = WScript.Arguments(1)
selectedDate = WScript.Arguments(2)
progressFile = WScript.Arguments(3)

'xlsPath = "C:\Users\Ivan\Desktop\Новая папка\Лист Microsoft Excel.xlsx"
'docxPath = "C:\Users\Ivan\Desktop\Новая папка\Документ Microsoft Word (3).docx"
'selectedDate = "01.01.2025"
'progressFile = "C:\Users\Ivan\Desktop\Новая папка\progress_01.txt"

' Константы
Const kayfNames = "α|β|γ|Δ|ε|ζ|η|θ|ι|κ|λ|μ|ν|ξ|ο|π|ρ|σ|τ|υ|φ|χ|ψ|ω"
Const criviNames = "альфа|бета|гамма|дельта|эпсилон|дзета|эта|тета|йота|каппа|лямбда|мю|ню|кси|омикрон|пи|ро|сигма|тау|ипсилон|фи|хи|пси|омега"
Const fignya = "кВ |сек "

Const wdCharacter = 1
Const wdCollapseEnd = 0

' Основной процесс обработки
Main

Sub Main()
    'On Error Resume Next
    
    ' Инициализация прогресса
    WriteProgress "[..........] 0% Подготовка к обработке"
    
    Dim fso, objWord, objExcel, objDoc, objWorkBook, objSheet
    Set fso = CreateObject("Scripting.FileSystemObject")
    
    ' Проверка файлов
    If Not fso.FileExists(xlsPath) Then
        WriteProgress "ERROR: Файл XLSX не найден: " & xlsPath
        WScript.Quit 2
    End If

    If Not fso.FileExists(docxPath) Then
        WriteProgress "ERROR: Файл DOCX не найден: " & docxPath
        WScript.Quit 3
    End If

    ' Преобразование даты
    Dim dateParts, d, m, y, processedDate
    dateParts = Split(selectedDate, ".")
    d = CInt(dateParts(0))
    m = CInt(dateParts(1))
    y = CInt(dateParts(2))
    processedDate = DateSerial(y, m, d)

    ' Открытие Word
    WriteProgress "[=.........] 10% Открытие документов"
    Set objWord = CreateObject("Word.Application")
    If Err.Number <> 0 Then
        WriteProgress "ERROR: Не удалось создать объект Word: " & Err.Description
        WScript.Quit 4
    End If
	
	' Оптимизация Word
    objWord.Visible = False
    objWord.DisplayAlerts = False
    objWord.ScreenUpdating = False
    
    Set objDoc = objWord.Documents.Open(docxPath, False, True)
    If Err.Number <> 0 Then
        WriteProgress "ERROR: Не удалось открыть DOCX: " & Err.Description
        objWord.Quit
        WScript.Quit 5
    End If
    
    If objDoc.ProtectionType <> 0 Then
        WriteProgress "WARNING: Документ защищен! Результаты могут быть некорректными."
    End If

    ' Открытие Excel
    WriteProgress "[==........] 20% Открытие Excel"
    Set objExcel = CreateObject("Excel.Application")
    If Err.Number <> 0 Then
        WriteProgress "ERROR: Не удалось создать объект Excel: " & Err.Description
        objDoc.Close False
        objWord.Quit
        WScript.Quit 6
    End If
	
	' Оптимизация Excel
    objExcel.Visible = False
    objExcel.DisplayAlerts = False
    objExcel.ScreenUpdating = False
    
    Set objWorkBook = objExcel.WorkBooks.Open(xlsPath)
    Set objSheet = objWorkBook.Sheets("Лист1")
	
	' Предварительная обработка данных Excel
    WriteProgress "[===.......] 30% Загрузка данных из Excel"
    Dim excelData, rowExcel, currentDate, currentPS, currentBefore, currentAfter, subDict
    Set excelData = CreateObject("Scripting.Dictionary")
    
    For rowExcel = 1 To objSheet.UsedRange.Rows.Count
        If IsDate(objSheet.Range("L" & rowExcel).Value) Then ' Столбец L
            currentDate = CDate(objSheet.Range("L" & rowExcel).Value)
            If currentDate >= processedDate Then
                currentPS = ClearStr(objSheet.Range("D" & rowExcel).Value)  ' Столбец D
                currentBefore = StyleStr(ClearStr(objSheet.Range("K" & rowExcel).Value)) ' Столбец K
                currentAfter = StyleStr(ClearStr(objSheet.Range("J" & rowExcel).Value))   ' Столбец J
                
                If currentPS <> "" Then
                    If Not excelData.Exists(currentPS) Then
						Set subDict = CreateObject("Scripting.Dictionary")
						subDict.Add subDict.Count, currentBefore & "|" & currentAfter
						excelData.Add currentPS, subDict
					Else
						Set subDict = excelData(currentPS)
						subDict.Add subDict.Count, currentBefore & "|" & currentAfter
					End If
                End If
            End If
        End If
    Next
    
    ' Очистка памяти Excel
    objWorkBook.Close False
    objExcel.Quit
    Set objExcel = Nothing
	
	' Кеш для замен
    Dim replaceCache
    Set replaceCache = CreateObject("Scripting.Dictionary")

	Dim changedCells, deletedCells, addedCells, processTable, totalTables, totalRows, itrRow
    changedCells = 0
    deletedCells = 0
    addedCells = 0
    processTable = 0
    totalTables = objDoc.Tables.Count
	totalRows = 0
	itrRow = -1
	For Each objTable In objDoc.Tables
		totalRows = totalRows + objTable.Rows.Count
	Next
	
	
	' Обработка таблиц
    Dim objTable, rowIndex, progressPercent, progressText
    Dim processedFeederArray()
    For Each objTable In objDoc.Tables
        processTable = processTable + 1
        ReDim processedFeederArray(-1)
        
        For rowIndex = objTable.Rows.Count To 1 Step -1
			itrRow = itrRow + 1
            ' Расчет прогресса
            progressPercent = 30 + Round((itrRow / totalRows) * 70, 0)
            progressText = "Обработка таблицы " & processTable & "/" & totalTables & _
                           " строка " & itrRow & "/" & totalRows
            
            ' Обновление прогресса каждые 10 строк
            If rowIndex Mod 10 = 0 Then
                ShowProgress progressPercent, progressText
            End If
			
			
			' Получение текста ячейки
            Dim cellRange, strWord
            Set cellRange = objTable.Cell(rowIndex, 2).Range
            cellRange.MoveEnd wdCharacter, -1
            strWord = cellRange.Text
            
            ' Извлечение ПС
            Dim PS
			PS = ""
			If UBound(Split(strWord, " ")) > 0 Then
				On Error Resume Next
				PS = Split(strWord, " ")(UBound(Split(strWord, " ")))
				On Error GoTo 0
				
			End If
			
			' Поиск данных в словаре
			If excelData.Exists(PS) Then
				Dim dataDict, key, data, Before, After
				Set dataDict = excelData(PS)  ' Получаем вложенный словарь
				
				' MsgBox UBound(dataDict.Keys) & " " & PS & " " & UBound(excelData.Keys)
				
				For Each key In dataDict.Keys
					data = Split(dataDict(key), "|")
					Before = data(0)
					After = data(1)
				
					' MsgBox Before & "/" & After
					
					' Обработка замен
					If Before <> "резерв" And Before <> "свободная" Then
						' Простая замена
						Dim resultStr
						
						resultStr = ReplaceFeeder(strWord, Before, After)
						
						If resultStr <> strWord Then
							' Проверка на удаление строки
							If After = "резерв" Or After = "свободная" Then
								objTable.Rows(rowIndex).Delete
								deletedCells = deletedCells + 1
								dataDict.Remove(key)  ' Удаляем элемент по ключу
								Exit For
							Else
								' Обновление ячейки
								Dim rgbCell
								rgbCell = RGB(255, 255, 0) ' Желтый
								
								' Сохраняем маркер конца ячейки
								Dim endMarker
								endMarker = Right(cellRange.Text, 1)
								
								' Устанавливаем текст
								cellRange.Text = resultStr
								
								' Восстанавливаем маркер
								cellRange.Collapse wdCollapseEnd
								cellRange.Text = endMarker
								
								' Закрашиваем ячейку
								objTable.Cell(rowIndex, 2).Shading.BackgroundPatternColor = rgbCell
								changedCells = changedCells + 1
								dataDict.Remove(key)  ' Удаляем элемент по ключу
								Exit For
							End If
						End If
					Else
						' Обработка резервных фидеров
						If After <> "резерв" And After <> "свободная" Then
							Dim voltage, feeder, feederStr, feederArray, flag
							voltage = "Исключение"
							
							' Определение напряжения							
							feederArray = Split(After, "+")
							For Each feeder In feederArray
								feederStr = LeaveOnlyNumbers(feeder)
								
								Select Case Len(feederStr)
									Case 4
										voltage = "6 кВ"
									Case 5
										voltage = "10 кВ"
								End Select
							Next
							
							If InStr(Replace(strWord, " ", ""), Replace(voltage & " " & PS, " ", "")) > 0 Then
								feederStr = ExtractFeederFromLine(strWord, "2")
								
								' MsgBox strWord & vbCrLf & feederStr & vbCrLf & ReplaceFeeder(objTable.Cell(rowIndex + 1, 2).Range.Text, feederStr, After), 0, "title"
								If Len(LeaveOnlyNumbers(feederStr)) = 4 Or Len(LeaveOnlyNumbers(feederStr)) = 5 Then
									' MsgBox strWord & vbCrLf & feederStr & vbCrLf & ReplaceFeeder(objTable.Cell(rowIndex + 1, 2).Range.Text, feederStr, After), 0, "title"
								
									Redim Preserve processedFeederArray(UBound(processedFeederArray) + 1)
									processedFeederArray(UBound(processedFeederArray)) = After
								
									objTable.Rows.Add objTable.Rows(rowIndex + 1)
									
									objTable.Cell(rowIndex + 1, 2).Range.Text = ReplaceFeeder(objTable.Cell(rowIndex, 2).Range.Text, feederStr, After)
									objTable.Cell(rowIndex + 1, 4).Range.Text = objTable.Cell(rowIndex, 4).Range.Text
									
									rgbCell = RGB(0, 255, 0)
									objTable.Cell(rowIndex + 1, 1).Shading.BackgroundPatternColor = rgbCell
									objTable.Cell(rowIndex + 1, 2).Shading.BackgroundPatternColor = rgbCell
									objTable.Cell(rowIndex + 1, 3).Shading.BackgroundPatternColor = rgbCell
									objTable.Cell(rowIndex + 1, 4).Shading.BackgroundPatternColor = rgbCell
									
									addedCells = addedCells + 1
									dataDict.Remove(key)  ' Удаляем элемент по ключу
									
									Exit For									
								End If
							End If
						End If
					End If
				Next
			End If
		Next
	Next

    ' Финализация
    ShowProgress 100, "Завершение обработки"
	
	' Включение обновления экрана
    objWord.ScreenUpdating = True

	' Автоматическое сохранение как копии
	Dim newDocPath
	newDocPath = fso.BuildPath(fso.GetParentFolderName(docxPath), _
				 fso.GetBaseName(docxPath) & "_обработанный_" & _
				 Year(Now) & Month(Now) & Day(Now) & "_" & _
				 Hour(Now) & Minute(Now) & Second(Now) & ".docx")

	objDoc.SaveAs newDocPath
	objDoc.Close
    objWord.Quit
    
    ' Итоговый отчет
    Dim resultMsg
    resultMsg = "[==========] 100% Обработка завершена!"& chr(13) & chr(10) &"Ячеек изменено: " & changedCells & chr(13) & chr(10) & "Ячеек удалено: " & deletedCells & chr(13) & chr(10) & "Ячеек добавлено: " & addedCells
    WriteProgress resultMsg
    
    ' Задержка для отображения финального сообщения
    WScript.Sleep 3000
    Set fso = Nothing
End Sub

Function LeaveOnlyNumbers(inputStr)
    Dim regex
    Set regex = New RegExp
    regex.Pattern = "[^0-9]"    ' Шаблон: все символы, НЕ являющиеся цифрами
    regex.Global = True          ' Применить ко всем вхождениям
    LeaveOnlyNumbers = regex.Replace(inputStr, "")
End Function

' Функция записи прогресса в файл
Sub WriteProgress(text)
    'On Error Resume Next
    Dim fso, file
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set file = fso.OpenTextFile(progressFile, 2, True) ' 2 = ForWriting
    file.Write text
    file.Close
End Sub

Sub ShowProgress(percent, message)
    Dim barLength, filled, bar, emptySpace
    barLength = 10
    filled = CInt(barLength * percent / 100)
    bar = String(filled, "=")
    emptySpace = String(barLength - filled, ".")
    
    Dim progressText
    progressText = "[" & bar & emptySpace & "] " & percent & "% " & message
    WriteProgress progressText
End Sub

' Вспомогательные функции
Function ClearStr(str)
    ClearStr = Trim(Replace(Replace(CStr(str), Chr(160), " "), Chr(9), ""))
End Function

Function StyleStr(str)
    Dim names, i
    names = Split(kayfNames, "|")
    For i = 0 To UBound(names)
        str = Replace(str, Split(criviNames, "|")(i), names(i))
    Next
    
    str = Replace(str, " ", "")

    Dim figArr, j
    figArr = Split(fignya, "|")
    For j = 0 To UBound(figArr)
        If InStr(str, figArr(j)) > 0 Then
            str = "" 
        End If
    Next

    Dim startDel, endDel
    startDel = InStr(str, "(")
    endDel = InStr(str, ")")
    If startDel > 0 And endDel > 0 Then
        str = Mid(str, 1, startDel-1) + Mid(str, endDel+1)
    End If

    StyleStr = str
End Function

Function HasGreek(str)
    Dim letters, i
    letters = Split(kayfNames, "|")
    HasGreek = False
    For i = 0 To UBound(letters)
        If InStr(str, letters(i)) > 0 Then
            HasGreek = True
            Exit Function
        End If
    Next
End Function

Function NormalizeFeeder(feederStr)
    Dim parts, i, j, temp
    parts = Split(Replace(feederStr, " ", ""), "+")
    For i = 0 To UBound(parts)
        For j = i + 1 To UBound(parts)
            If parts(i) > parts(j) Then
                temp = parts(i)
                parts(i) = parts(j)
                parts(j) = temp
            End If
        Next
    Next
    NormalizeFeeder = Join(parts, "+")
End Function

' Функция для определения фидера в строке с учетом переменной before
Function ExtractFeederFromLine(line, before)
    ' Очистка строки от лишних пробелов и переносов
    line = CleanLine(line)
    Dim prefix, startPos, endPos, feeder, parts, i, inFid, current, char
    Dim candidate, bestCandidate, maxMatchLength
    
    ' Инициализация
    prefix = "фид"
    startPos = 0
    endPos = 0
    feeder = ""
    bestCandidate = ""
    maxMatchLength = 0
    
    ' Поиск начала фидера (основной алгоритм)
    startPos = InStr(1, line, prefix & ". ", vbTextCompare)
    If startPos = 0 Then startPos = InStr(1, line, prefix & " ", vbTextCompare)
    If startPos = 0 Then startPos = InStr(1, line, prefix & ".", vbTextCompare)
    
    ' Если найдено начало через "фид"
    If startPos > 0 Then
        startPos = startPos + Len(prefix) + 1
        
        ' Поиск конца фидера
        endPos = InStr(startPos, line, " с ПС", vbTextCompare)
        If endPos = 0 Then endPos = InStr(startPos, line, "с ПС", vbTextCompare)
        If endPos = 0 Then endPos = Len(line) + 1
        
        ' Извлечение фидера
        feeder = Mid(line, startPos, endPos - startPos)
        feeder = Trim(feeder)
        
        ' Обработка составных фидеров
        If InStr(feeder, "+") > 0 Then
            parts = Split(feeder, "+")
            For i = 0 To UBound(parts)
                parts(i) = Trim(parts(i))
            Next
            feeder = Join(parts, "+")
        Else
            ' Удаление пробелов в простых фидерах
            feeder = Replace(feeder, " ", "")
        End If
    End If
    
    ' Дополнительный поиск по частичному совпадению с before
    If feeder = "" And before <> "" Then
        ' Нормализуем before для поиска
        Dim cleanBefore
        cleanBefore = Replace(Replace(before, " ", ""), "+", "\+")
        
        ' Создаем regex-шаблон для поиска частей before
        Dim re, matches, match
        Set re = New RegExp
        re.Pattern = "[" & cleanBefore & "]{3,}"
        re.IgnoreCase = True
        re.Global = True
        
        Set matches = re.Execute(line)
        For Each match In matches
            candidate = match.Value
            ' Если кандидат длиннее предыдущего лучшего
            If Len(candidate) > maxMatchLength Then
                maxMatchLength = Len(candidate)
                bestCandidate = candidate
            End If
        Next
        
        ' Если нашли подходящего кандидата
        If bestCandidate <> "" Then
            ' Проверяем, что кандидат окружен правильными символами
            Dim pos, beforeChar, afterChar
            pos = InStr(line, bestCandidate)
            If pos > 1 Then
                beforeChar = Mid(line, pos - 1, 1)
            Else
                beforeChar = " "
            End If
            
            If pos + Len(bestCandidate) <= Len(line) Then
                afterChar = Mid(line, pos + Len(bestCandidate), 1)
            Else
                afterChar = " "
            End If
            
            ' Если кандидат отделен пробелами или знаками препинания
            If Not IsValidChar(beforeChar) And Not IsValidChar(afterChar) Then
                feeder = bestCandidate
            End If
        End If
    End If
    
    ' Возвращаем результат
    ExtractFeederFromLine = feeder
End Function

' Функция очистки строки
Function CleanLine(line)
    ' Замена переносов строк и табуляций на пробелы
    line = Replace(line, Chr(13), " ")
    line = Replace(line, Chr(10), " ")
    line = Replace(line, Chr(9), " ")
    
    ' Удаление двойных пробелов
    Do While InStr(line, "  ") > 0
        line = Replace(line, "  ", " ")
    Loop
    
    CleanLine = Trim(line)
End Function

' Проверка является ли символ частью слова
Function IsValidChar(char)
    Dim validChars
    validChars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюяαβγδεζηθικλμνξοπρστυφχψω-"
    IsValidChar = InStr(validChars, char) > 0
End Function

' Основная функция замены фидера
Function ReplaceFeeder(line, oldFeeder, newFeeder)
    ' Извлекаем кандидата на фидер с помощью улучшенной функции
    Dim candidate, rawFeeder, startPos, length
    Dim extractionResult
    extractionResult = ExtractFeederWithPosition(line, oldFeeder)
    
    ' Если фидер не найден, возвращаем исходную строку
    If IsEmpty(extractionResult) Then
        ReplaceFeeder = line
        Exit Function
    End If
    
    ' Разбираем результат извлечения
    candidate = extractionResult(0)    ' Очищенный фидер
    rawFeeder = extractionResult(1)    ' Оригинальная подстрока
    startPos = extractionResult(2)     ' Начальная позиция
    length = extractionResult(3)       ' Длина подстроки
    
    ' Нормализуем для сравнения (игнорируем пробелы и порядок частей)
    Dim normCandidate, normOld
    normCandidate = NormalizeFeeder(candidate)
    normOld = NormalizeFeeder(oldFeeder)
    
    ' Отладочная информация (можно закомментировать после тестирования)
    'MsgBox "Старый фидер: " & normOld & vbCrLf & _
    '       "Найденный фидер: " & normCandidate & vbCrLf & _
    '       "Новый фидер: " & newFeeder, 0, "Сравнение фидеров"
    '
    ' Если нормализованные формы совпадают - выполняем замену
    If normCandidate = normOld Then
        ReplaceFeeder = Left(line, startPos - 1) & newFeeder & Mid(line, startPos + length)
    Else
        ReplaceFeeder = line
    End If
End Function

' Функция извлечения фидера с позицией (возвращает массив [clean_feeder, raw_feeder, start, length])
Function ExtractFeederWithPosition(line, before)
    ' Очистка строки
    line = CleanLine(line)
    Dim prefix, startPos, endPos, feeder, rawFeeder, parts, i
    Dim candidate, bestCandidate, maxMatchLength, candidatePos
    
    ' Инициализация
    prefix = "фид"
    startPos = 0
    endPos = 0
    rawFeeder = ""
    bestCandidate = ""
    candidatePos = 0
    maxMatchLength = 0
    
    ' Поиск по формату "фид"
    startPos = InStr(1, line, prefix & ". ", vbTextCompare)
    If startPos = 0 Then startPos = InStr(1, line, prefix & " ", vbTextCompare)
    If startPos = 0 Then startPos = InStr(1, line, prefix & ".", vbTextCompare)
    
    ' Если нашли формат "фид"
    If startPos > 0 Then
        startPos = startPos + Len(prefix)
        
        ' Пропускаем пробелы и точки после "фид"
        Do While Mid(line, startPos, 1) = " " Or Mid(line, startPos, 1) = "."
            startPos = startPos + 1
            If startPos > Len(line) Then Exit Do
        Loop
        
        ' Поиск конца фидера
        endPos = InStr(startPos, line, " с ПС", vbTextCompare)
        If endPos = 0 Then endPos = InStr(startPos, line, "с ПС", vbTextCompare)
        If endPos = 0 Then endPos = Len(line) + 1
        
        ' Извлекаем оригинальную подстроку
        rawFeeder = Mid(line, startPos, endPos - startPos)
        feeder = Trim(rawFeeder)
        
        ' Обработка составных фидеров
        If InStr(feeder, "+") > 0 Then
            parts = Split(feeder, "+")
            For i = 0 To UBound(parts)
                parts(i) = Trim(parts(i))
            Next
            feeder = Join(parts, "+")
        Else
            ' Для простых фидеров удаляем все пробелы
            feeder = Replace(feeder, " ", "")
        End If
        
        ' Возвращаем результат
        ExtractFeederWithPosition = Array(feeder, rawFeeder, startPos, Len(rawFeeder))
        Exit Function
    End If
    
    ' Поиск по частичному совпадению с before
    If before <> "" Then
        ' Создаем regex-шаблон для поиска
        Dim re, matches, match
        Set re = New RegExp
        re.Pattern = "\b(" & Replace(Replace(before, " ", ""), "+", "\\+") & ")\b"
        re.IgnoreCase = True
        re.Global = True
        
        Set matches = re.Execute(line)
        For Each match In matches
            candidate = match.Value
            ' Ищем самое длинное совпадение
            If Len(candidate) > maxMatchLength Then
                maxMatchLength = Len(candidate)
                bestCandidate = candidate
                candidatePos = match.FirstIndex + 1
            End If
        Next
        
        ' Если нашли подходящего кандидата
        If bestCandidate <> "" Then
            ' Проверяем контекст
            Dim beforeChar, afterChar
            If candidatePos > 1 Then
                beforeChar = Mid(line, candidatePos - 1, 1)
            Else
                beforeChar = " "
            End If
            
            If candidatePos + Len(bestCandidate) <= Len(line) Then
                afterChar = Mid(line, candidatePos + Len(bestCandidate), 1)
            Else
                afterChar = " "
            End If
            
            ' Если кандидат отделен пробелами или знаками препинания
            If Not IsValidChar(beforeChar) And Not IsValidChar(afterChar) Then
                ' Для составных фидеров ищем полный контекст
                Dim fullCandidate, endPosCandidate
                fullCandidate = bestCandidate
                endPosCandidate = candidatePos + Len(bestCandidate) - 1
                
                ' Проверяем соседние символы на наличие операторов
                If candidatePos > 1 And Mid(line, candidatePos - 1, 1) = "+" Then
                    fullCandidate = "+" & fullCandidate
                    candidatePos = candidatePos - 1
                End If
                
                If endPosCandidate < Len(line) And Mid(line, endPosCandidate + 1, 1) = "+" Then
                    fullCandidate = fullCandidate & "+"
                    endPosCandidate = endPosCandidate + 1
                End If
                
                ' Возвращаем результат
                ExtractFeederWithPosition = Array(bestCandidate, fullCandidate, candidatePos, Len(fullCandidate))
                Exit Function
            End If
        End If
    End If
    
    ' Если ничего не найдено
    ExtractFeederWithPosition = Empty
End Function

' Функция очистки строки фидера
Function CleanFeederString(feeder)
    ' Удаляем запрещенные символы
    Dim invalidChars, i
    invalidChars = Array("(", ")", "[", "]", "{", "}", "|", "\", "/", "'", """", "`")
    For i = 0 To UBound(invalidChars)
        feeder = Replace(feeder, invalidChars(i), "")
    Next
    
    ' Удаляем двойные пробелы
    Do While InStr(feeder, "  ") > 0
        feeder = Replace(feeder, "  ", " ")
    Loop
    
    CleanFeederString = Trim(feeder)
End Function