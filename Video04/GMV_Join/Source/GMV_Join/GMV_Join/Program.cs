using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

//Утилита для склеивания картинок и звука в видеофайл формата GMV и GMM

namespace GMV_Join
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Утилита для подготовки видеофайла формата GMV, GMM, ZXV");
            Console.WriteLine("Укажите аргументы: Файлы картинки, Файл звука, Задержка в кадрах, Тип видео");

            if (args.Length < 4)
            {
                Console.WriteLine("Не все аргументы");
                return;
            }
            string file_in_sampl = args[0]; //Общее имя входного файла
            string file_in_sound = args[1]; //имя входного файла звука
            int syncro = Convert.ToInt16(args[2]); //Задержка в кадрах до начала изображения
            int offset_pic = 0; //отступ чтобы пропустить заголовок картинки
            int size_pic = 0; //размер картинки
            int sound_frame = 0; //размер кадра аудио
            int sound_frame_max = 0; //размер кадра аудио максимум
            string file_out = ""; //имя выходного файла
            string file_in_ext = ""; //расширение входного файла
            bool check = false; //флаг что параметры приняты

            if (args[3].ToUpper() == "GMV") //зададим переменные  в зависимости от типа
            {//GMV
                sound_frame = 1124 * 2; //для 22050 моно 10 кадр/с
                sound_frame_max = 4096;
                offset_pic = 128;
                size_pic = 16384;
                file_in_ext = ".c";
                file_out = "VIDEO.GMV"; //имя выходного файла
                check = true;
            }
            if (args[3].ToUpper() == "GMM")
            {//GMM
                sound_frame = 1124 * 2; //для 11025 моно 5 кадр/с; 
                sound_frame_max = 4096;
                offset_pic = 0 ;
                size_pic = 32768;
                file_in_ext = ".c";
                file_out = "VIDEO.GMM"; //имя выходного файла
                check = true;
            }
            if (args[3].ToUpper() == "ZXV")
            {//иначе считаем что ZXV
                sound_frame = 1124 * 2; //для 22050 моно 10 кадр/с 
                sound_frame_max = 4096;
                offset_pic = 0 ;
                size_pic = 8192;
                file_in_ext = ".scr";
                file_out = "VIDEO.ZXV"; //имя выходного файла
                check = true;
            }

            if (!check) return; //выход если параметры не приняты

            byte[] data_file = new byte[1000000]; //буфер для входящего файла
            byte[] data_file_snd = new byte[1000000]; //буфер для входящего файла звуаа
            //byte[] data_out = new byte[1000000]; //буфер для выходного файла

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

            for (int i = 0; i < syncro; i++) //сначала будет звук без изображения для буферизации
            {
                FS_In_Snd.Read(data_file_snd, 0, sound_frame); //прочитаем кусок звука

                if (args[3].ToUpper() == "GMV")
                {
                    Array.Copy(data_file_snd, 2048, data_file_snd, sound_frame_max + 16000, sound_frame - 2048);//Продублируем последнюю часть звука ещё и после картинки
                }
                if (args[3].ToUpper() == "GMM")
                {
                    Array.Copy(data_file_snd, 2048, data_file_snd, sound_frame_max + 16000+16384, sound_frame - 2048);//Продублируем последнюю часть звука ещё и после картинки
                }
                if (args[3].ToUpper() == "ZXV")
                {
                    Array.Copy(data_file_snd, 2048, data_file_snd, sound_frame_max + 6912, sound_frame - 2048);//Продублируем последнюю часть звука ещё и после картинки
                }

                FS_Out.Write(data_file_snd, 0, sound_frame_max + size_pic); //запишем один кадр звука и пустоту в конце
            }


            int frame_all = 0; //всего кадров
            for (int i = 0; i < 100000; i++) //номер файла и цикл
            {

                string file_in = file_in_sampl + i.ToString("D5") + file_in_ext; //имя файла дополняем номером и расширением
                if (File.Exists(file_in)) //если файл существует
                {
                FS_In_Snd.Read(data_file_snd, 0, sound_frame); //прочитаем кусок звука
                FS_Out.Write(data_file_snd, 0, sound_frame_max); //запишем один кадр звука и пустоту в конце

                Console.WriteLine("Добавление файла " + i.ToString("D5"));
                FileStream FS_In = new FileStream(file_in, FileMode.Open); //открываем входной файл
                int file_in_lenght = Convert.ToInt32(FS_In.Length); //длина файла
                if (file_in_lenght == 6144) //если картинка без атрибутов, заполним атрибуты
                {
                    for (int i_f = 6144;  i_f < 6912; i_f++)
                        data_file[i_f] = 7*8; //цвет
                }
                FS_In.Read(data_file, 0, file_in_lenght); //прочитаем
                FS_In.Close();

                if (args[3].ToUpper() == "GMV")
                {
                    Array.Copy(data_file_snd, 2048, data_file, 16128, sound_frame - 2048);//Продублируем последнюю часть звука ещё и после картинки
                }
                if (args[3].ToUpper() == "GMM")
                {
                    Array.Copy(data_file_snd, 2048, data_file, 16000 + 16384, sound_frame - 2048);//Продублируем последнюю часть звука ещё и после картинки
                }
                if (args[3].ToUpper() == "ZXV")
                {
                    Array.Copy(data_file_snd, 2048, data_file, 6912, sound_frame - 2048);//Продублируем последнюю часть звука ещё и после картинки
                }

                FS_Out.Write(data_file, offset_pic, size_pic); //запишем одну картинку

                frame_all++; //прибавим счётчик
                }

            }
            FS_Out.Close();
            Console.WriteLine("Всего добавлено кадров: " + frame_all.ToString());             

        }
    }
}
