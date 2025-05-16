@ECHO OFF
echo Project %~n1
SET TDIR=%~sdp0temp
SET PDIR=%~sdpn1
SET BIN=%~sdp0bin
IF NOT EXIST "%PDIR%" mkdir "%PDIR%"
IF NOT EXIST %TDIR% mkdir %TDIR%
del /Q /F %TDIR%\*.*
copy /Y /B %BIN%\DISK.trd %PDIR%\VPlayer.trd
cd %TDIR%
set FFREPORT=file=volum.log
echo Analising volume... 
%BIN%\ffmpeg -loglevel error -report -i %1 -af "volumedetect" -vn -sn -dn -f null NUL

FOR /F "eol=; tokens=6,7,8 delims=_: " %%i in (volum.log) do (
	IF "%%i"=="histogram" (
		IF %%k GEQ 100 (
			SET DBFIX=%%j
			goto DBFIXEND
		)
	)
)
:DBFIXEND
echo Volume fixing %DBFIX:~0,-2%dB
echo Convert audio...
%BIN%\ffmpeg -loglevel error -y -i %1 -f u8 -ar 22500 -ac 1 -filter:a "volume=%DBFIX:~0,-2%dB" -vn %TDIR%/audio.bin
echo Generating frames...
%BIN%\ffmpeg -loglevel error -y -i %1 -i %BIN%\pal.png -filter_complex "[0:v]fps=10,scale=-1:200[b];[b][1:v]paletteuse" -an %TDIR%/b%%05d.bmp
echo Converting frames...
%BIN%\Img2GMX.exe %TDIR%\b
echo Build video file...
%BIN%\GMV_Join.exe %TDIR%\b %TDIR%\audio.bin 30 gmv
move %TDIR%\VIDEO.GMV "%PDIR%\%~n1.GMV" 
echo All operations completed
echo Converted video in to directory %PDIR%

pause
