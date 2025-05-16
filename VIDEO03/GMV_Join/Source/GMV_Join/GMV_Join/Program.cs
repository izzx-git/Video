using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

//Утилита для склеивания картинок и звука в видеофайл формата GMV

namespace GMV_Join
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Утилита для склеивания картинок и звука в видеофайл формата GMV");
            Console.WriteLine("Укажите аргументы: Файл картинки, Файл звука, Задержка в кадрах");

            if (args.Length < 3)
            {
                Console.WriteLine("Не все аргументы");
                return;
            }
            string file_in_sampl = args[0]; //Общее имя входного файла
            string file_in_sound = args[1]; //имя входного файла звука
            int syncro = Convert.ToInt16(args[2]); //Задержка в кадрах до начала изображения

            int sound_frame = 1104; //размер кадра аудио
            int sound_frame_max = 2048; //размер кадра аудио максимум
            //string path = Directory.GetCurrentDirectory(); //узнать текущий путь
            //string file_in_sampl = "scene"; //Общее имя входного файла
            //string file_in_sound = "sound.wav"; //имя входного файла звука
            byte[] data_file = new byte[1000000]; //буфер для входящего файла
            byte[] data_file_snd = new byte[1000000]; //буфер для входящего файла звуаа
            //byte[] data_out = new byte[1000000]; //буфер для выходного файла
            string file_out = "VIDEO.GMV"; //имя выходного файла

            FileStream FS_Out = null; //выходной поток
            if (File.Exists(file_out))
            {
                File.Delete(file_out); //удалить старый файл
                FS_Out = new FileStream(file_out, FileMode.Create); //создаём выходной файл
                //FS_Out = new FileStream(file_out, FileMode.Open); //открываем выходной файл
            }
            else
            {
                FS_Out = new FileStream(file_out, FileMode.Create); //создаём выходной файл
            }

            FileStream FS_In_Snd = null; //входной поток звука
            if (File.Exists(file_in_sound)) //есть ли файл звука?
            {
                FS_In_Snd = new FileStream(file_in_sound, FileMode.Open); //открываем входной файл звука
            }
            else
            {
                Console.WriteLine("Файл не найден: " + file_in_sound);
                return; //выход если нет
            }

            FS_In_Snd.Read(data_file_snd, 0, 58); //прочитаем заголовок звука, чтобы пропустить его

            for (int i = 0; i <= syncro; i++) //сначала будет звук без изображения для буферизации
            {
                FS_In_Snd.Read(data_file_snd, 0, sound_frame); //прочитаем кусок звука
                FS_Out.Write(data_file_snd, 0, sound_frame_max + 16000 + 384 + 2048); //запишем один кадр звука и пустоту в конце
            }


            int frame_all = 0; //всего кадров
            for (int i = 0; i <= 100000; i++) //номер файла и цикл
            {

                string file_in = file_in_sampl + i.ToString("D5") + ".C"; //имя файла дополняем номером и расширением
                if (File.Exists(file_in)) //если файл существует
                {
                FS_In_Snd.Read(data_file_snd, 0, sound_frame); //прочитаем кусок звука
                FS_Out.Write(data_file_snd, 0, sound_frame_max); //запишем один кадр звука и пустоту в конце

                Console.WriteLine("Добавление файла " + i.ToString("D5"));
                FileStream FS_In = new FileStream(file_in, FileMode.Open); //открываем входной файл
                int file_in_lenght = Convert.ToInt32(FS_In.Length); //длина файла
                FS_In.Read(data_file, 0, file_in_lenght); //прочитаем
                FS_In.Close();
                //Array.Copy(data_file, 128, data_out, 0, 16000); //копировать часть картинки без заголовка в выходной буфер
                FS_Out.Write(data_file, 128, 16000 + 384 + 2048); //запишем одну картинку без заголовка и пустоту в конце

                frame_all++; //прибавим счётчик
                }

            }
            FS_Out.Close();
            Console.WriteLine("Всего добавлено кадров: " + frame_all.ToString());             

        }
    }
}
