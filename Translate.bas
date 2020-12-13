﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=7.8
@EndOfDesignText@
'Handler class
Sub Class_Globals
	
End Sub

Public Sub Initialize
	
End Sub

Sub Handle(req As ServletRequest, resp As ServletResponse)
	If req.ContentType.StartsWith("multipart/form-data") Then
		Dim uploadedPath As String=File.Combine(File.DirApp,"uploaded")
		If File.Exists(uploadedPath,"")=False Then
			File.MakeDir(uploadedPath,"")
		End If
		Dim parts As Map = req.GetMultipartData(File.DirApp & "/uploaded", 10000000)
		Dim filepart As Part = parts.Get("image")
		Dim configpart As Part = parts.Get("config")
		Dim config As String
		config=configpart.GetValue(req.CharacterEncoding)
		Dim detectOnly As String="false"
		If parts.ContainsKey("detectonly") Then
			Dim detectpart As Part = parts.Get("detectonly")
			If detectpart.GetValue(req.CharacterEncoding)="on" Then
				detectOnly="true"
			Else
				detectOnly="false"
			End If
		End If
		Dim returntype As String
		Dim returntypePart As Part=parts.Get("returntype")
		returntype=returntypePart.GetValue(req.CharacterEncoding)
		Dim hash As String=MD5(filepart.TempFile,"")
		File.Copy(filepart.TempFile,"",uploadedPath,filepart.SubmittedFilename)
		File.Delete(filepart.TempFile,"")
		Log(filepart.SubmittedFilename)
		Dim configPath As String=WriteConfigFile(config)
		Dim fileListPath As String=WriteFileList(File.Combine(uploadedPath,filepart.SubmittedFilename))
		Run(resp,configPath,fileListPath,detectOnly,hash,returntype)
		StartMessageLoop '<---
	Else
		resp.Write("wrong")
	End If
End Sub

Sub WriteConfigFile(config As String) As String
	Dim path As String=File.Combine(Main.tempDir,DateTime.Now&".json")
	File.WriteString(path,"",config)
	Return path
End Sub

Sub WriteFileList(filename As String) As String
	Dim path As String=File.Combine(Main.tempDir,DateTime.Now&".txt")
	File.WriteString(path,"",filename)
	Return path
End Sub

Sub Run(resp As ServletResponse,configPath As String,fileListPath As String,detectOnly As String,hash As String,returntype As String)
	' .\config.json true true .\temp2\ .\fileList.txt
	Try
		
		Dim sh As Shell
		sh.Initialize("sh","java",Array As String("-jar","ImageTrans.jar",configPath,"true",detectOnly,Main.tempDir,fileListPath))
		sh.WorkingDirectory=File.DirApp
		sh.Encoding=GetSystemProperty("file.encoding","UTF8")
		sh.run(1000000)
		wait for sh_ProcessCompleted (Success As Boolean, ExitCode As Int, StdOut As String, StdErr As String)
		If Success And ExitCode = 0 Then
			Log("Success")
			Log(StdOut)
			Dim workDir As String=File.Combine(Main.tempDir,hash)
			If returntype="json" Then
				resp.ContentType="application/json"
				If File.Exists(workDir,"auto.json") Then
					resp.Write(File.ReadString(workDir,"auto.json"))
				Else
					resp.Write("[]")
				End If
			Else if returntype="html" Then
				resp.ContentType="text/html"
				resp.Write($"<img src="/temp/${hash}/image.jpg-output.jpg"  alt="result" />"$)
			End If

		Else
			Log(StdOut)
		End If
	Catch
		Log(LastException)
		resp.Write(LastException.Message)
	End Try
	StopMessageLoop
End Sub

Sub MD5(dir As String,filename As String) As String
	Dim in As InputStream
	in = File.OpenInput(dir,filename)
	Dim buffer(File.Size(dir, filename)) As Byte
	in.ReadBytes(buffer, 0, buffer.length)
	Dim Bconv As ByteConverter
	Dim data(buffer.Length) As Byte
	Dim md As MessageDigest
	data = md.GetMessageDigest(buffer, "MD5")
	Return Bconv.HexFromBytes(data)
End Sub