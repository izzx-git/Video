using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Drawing;
using System.IO;

namespace Img2GMX
{
    class Program
    {
        static void Main(string[] args)
        {
            //Конвертор картинок в формат GMX 160*200
            string file = ""; //путь 
            if (args.Length == 0) file = @"C:\Users\Admin\DOWNLO~1\zx\Develop\Video\VIDEO04.01\temp\b"; //если, не передали путь
            else file = args[0]; //получим путь и имя
            //System.Console.WriteLine(file);
            string file_in = "";
            string file_out = "";

            for (int i = 0; i < 100000; i++) //номер файла и цикл
            {

                file_in = file + i.ToString("D5") + ".bmp"; //имя файла дополняем номером и расширением
                if (File.Exists(file_in)) //если файл существует
                {

                    file_out = file + i.ToString("D5") + ".C";  //путь выходной файл
                    FileStream FS_out = new FileStream(file_out, FileMode.Create); //создаём выходной файл

                    byte[] byte_out = new byte[128]; //массив для заголовка
                    byte_out[0] = Convert.ToByte('G');
                    byte_out[1] = Convert.ToByte('M');
                    byte_out[2] = Convert.ToByte('X');
                    byte_out[3] = Convert.ToByte(15);
                    FS_out.Write(byte_out, 0, 128); //запишем в файл заголовок

                    Bitmap myBitmap = new Bitmap(file_in);
                    int widthIn = myBitmap.Size.Width; //ширина исходная
                    int widthOut = 320; //ширина выходная
                    int left = (widthIn - 320) / 2; //отступ слева
                    int heightIn = myBitmap.Size.Height; //высота исходная
                    Color pixelColor = new Color();
                    for (int y = 0; y < heightIn; y++) //цикл строка
                    {
                        for (int x = 0; x < widthOut; x += 4) //цикл столбец
                        {
                            int brightFlag = 0; //флаг повышенной яркости
                            int colorL = 0;
                            int colorR = 0;
                            string pixcolor = "";

                            if ((x + left) >= 0 && (x + left) < widthIn)
                            {
                                pixelColor = myBitmap.GetPixel(x + left, y); //получить цвет пикселя
                                pixcolor = pixelColor.Name;
                                colorL = detColor(pixcolor); //получить цвет в формат ZX, левый пиксель
                                if (colorL > 7)
                                { brightFlag = 1; colorL -= 8; }//если цвет с повышенной яркостью, включаем флаг
                            }

                            if ((x + left + 1) >= 0 && (x + left + 1) < widthIn)
                            {
                                pixelColor = myBitmap.GetPixel(x + left + 1, y); //получить цвет пикселя
                                pixcolor = pixelColor.Name;
                                colorR = detColor(pixcolor); //получить цвет в формат ZX, правый пиксель
                                if (colorR > 7)
                                { brightFlag = 1; colorR -= 8; }
                            }

                            int colorOut = brightFlag * 64 + colorL * 8 + colorR; //скомбинировать левый и правый
                            byte_out[0] = Convert.ToByte(colorOut);
                            FS_out.Write(byte_out, 0, 1); //запишем байт в файл
                        }
                    }
                    FS_out.Close();
                }

            }


        
        }
        static int detColor(string readbuf)
        {//преобразует цвет RGB из 3 байт в цвет 4 бита 0-15
            string[] colorsRGB = new string[]// объявляем текстовый массив и перечисляем цвета
                 {  "000000", 
                    "0000c0",
                    "c00000",
                    "c000c0",
                    "00c000",                  
                    "00c0c0",
                    "c0c000",
                    "c0c0c0",
                    "000000",
                    "0000ff",
                    "ff0000",
                    "ff00ff",
                    "00ff00",
                    "00ffff",
                    "ffff00",
                    "ffffff"
                };
            int color = 0;
            readbuf = readbuf.Remove(0, 2); //убрать лишние символы
            readbuf = readbuf.ToLower(); //в нижний регистр
            for (int i = 0; i < 16; i++)
            {
                if (colorsRGB[i] == readbuf)
                {
                    color = i;
                }
            }
            if (color == 8) color = 0; //чёрный 8 = чёрный 0
            return color;
        }
    }
}
