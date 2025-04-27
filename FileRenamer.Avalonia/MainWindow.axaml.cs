using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Threading;
using Avalonia.Platform.Storage;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace FileRenamer.Avalonia
{
    public class AppSettings
    {
        public int ImageCounter { get; set; } = 1;
        public int VideoCounter { get; set; } = 1;
    }

    public partial class MainWindow : Window
    {
        private AppSettings _settings = null!;

        private static readonly HashSet<string> ImageExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            { "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif", "svg", "ico", "raw", "arw", "cr2", "nef", "orf", "rw2", "dng" };
        private static readonly HashSet<string> VideoExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            { "mp4", "m4v", "mov", "avi", "mkv", "wmv", "flv", "webm", "mpeg", "mpg", "m2ts", "mts", "ts", "vob", "3gp", "3g2", "rm", "rmvb", "ogv" };

        public MainWindow()
        {
            InitializeComponent();
            LoadSettingsAndUpdateUi();
        }

        private void Window_DragOver(object? _, DragEventArgs e)
        {
            e.Handled = true;
            if (!e.Data.Contains(DataFormats.Files))
            {
                 e.DragEffects = DragDropEffects.None;
                 return;
            }
            e.DragEffects = DragDropEffects.Copy;
        }

        private async void Window_Drop(object? _, DragEventArgs e)
        {
             e.Handled = true;

            if (e.Data.Contains(DataFormats.Files))
            {
                var storageItems = e.Data.GetFiles();
                if (storageItems == null) return;

                var filePaths = storageItems
                    .OfType<IStorageFile>()
                    .Select(f => f.TryGetLocalPath())
                    .Where(p => !string.IsNullOrEmpty(p))
                    .Select(p => p!)
                    .ToList();

                if (filePaths.Any())
                {
                    string resultMessage = await Task.Run(() => ProcessDroppedFiles(filePaths));
                    Console.WriteLine(resultMessage);
                }
            }
        }

        private string ProcessDroppedFiles(IEnumerable<string> filePaths)
        {
            int successCount = 0;
            int failCount = 0;

            foreach (var filePath in filePaths)
            {
                if (RenameDroppedFile(filePath))
                {
                    successCount++;
                }
                else
                {
                    failCount++;
                }
            }

            Dispatcher.UIThread.Post(() => {
                UpdateUiCounters();
                SaveSettings();
            });

            return $"成功重命名 {successCount} 个文件，失败 {failCount} 个。";
        }

        private bool RenameDroppedFile(string filePath)
        {
            var fileInfo = ExtractFileInfo(filePath);
            if (fileInfo == null)
            {
                Console.WriteLine($"无法解析文件信息: {filePath}");
                return false;
            }

            string ext = fileInfo.Value.Extension;
            int currentCounter = GetCurrentCounter(ext);

            if (currentCounter == -1)
            {
                Console.WriteLine($"不支持的文件类型: {ext} ({filePath})");
                return false;
            }

            string? newFilename = null;
            string? destinationPath = null;
            int attempts = 0;
            const int maxAttempts = 10;

            do
            {
                newFilename = GenerateNewFilename(ext, currentCounter);
                if (newFilename == null) return false;

                destinationPath = Path.Combine(fileInfo.Value.Directory, newFilename);

                if (!File.Exists(destinationPath))
                {
                    break;
                }

                currentCounter++;
                attempts++;

            } while (attempts < maxAttempts);

            if (destinationPath == null || attempts >= maxAttempts)
            {
                Console.WriteLine($"无法为 {filePath} 找到可用的新文件名（尝试了 {attempts} 次）。");
                return false;
            }

            if (PerformRename(filePath, destinationPath))
            {
                IncrementAndSetCounter(ext, currentCounter + 1);
                return true;
            }
            else
            {
                return false;
            }
        }

        private (string Directory, string NameWithoutExtension, string Extension)? ExtractFileInfo(string filePath)
        {
            try
            {
                string directory = Path.GetDirectoryName(filePath) ?? string.Empty;
                string nameWithoutExtension = Path.GetFileNameWithoutExtension(filePath);
                string extension = Path.GetExtension(filePath) ?? string.Empty;

                if (string.IsNullOrEmpty(directory) || string.IsNullOrEmpty(nameWithoutExtension) || string.IsNullOrEmpty(extension))
                {
                    return null;
                }
                string cleanedExtension = extension.TrimStart('.').ToLowerInvariant();
                 if (string.IsNullOrEmpty(cleanedExtension)) return null;

                return (directory, nameWithoutExtension, cleanedExtension);
            }
            catch (ArgumentException ex)
            {
                 Console.WriteLine($"提取文件信息时出错 '{filePath}': {ex.Message}");
                 return null;
            }
        }

        private int GetCurrentCounter(string fileExtension)
        {
            if (ImageExtensions.Contains(fileExtension))
            {
                return _settings.ImageCounter;
            }
            else if (VideoExtensions.Contains(fileExtension))
            {
                return _settings.VideoCounter;
            }
            return -1;
        }

        private string? GenerateNewFilename(string fileExtension, int counter)
        {
            string prefix;
            if (ImageExtensions.Contains(fileExtension))
            {
                prefix = "IMG_";
            }
            else if (VideoExtensions.Contains(fileExtension))
            {
                prefix = "VID_";
            }
            else
            {
                return null;
            }
            return $"{prefix}{counter:D5}.{fileExtension}";
        }

        private bool PerformRename(string sourcePath, string destinationPath)
        {
            try
            {
                File.Move(sourcePath, destinationPath);
                Console.WriteLine($"Renamed: {Path.GetFileName(sourcePath)} -> {Path.GetFileName(destinationPath)}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"重命名失败: {sourcePath} 到 {destinationPath}. 错误: {ex.Message}");
                return false;
            }
        }

        private void IncrementAndSetCounter(string fileExtension, int nextCounterValue)
        {
             if (nextCounterValue > 99999) nextCounterValue = 99999;

            if (ImageExtensions.Contains(fileExtension))
            {
                _settings.ImageCounter = nextCounterValue;
            }
            else if (VideoExtensions.Contains(fileExtension))
            {
                _settings.VideoCounter = nextCounterValue;
            }
        }

        private void UpdateUiCounters()
        {
             var imageCounterDisplay = this.FindControl<TextBlock>("ImageCounterDisplay");
            if (imageCounterDisplay != null)
            {
                imageCounterDisplay.Text = $"下一个图片编号: {_settings.ImageCounter:D5}";
            }

            var videoCounterDisplay = this.FindControl<TextBlock>("VideoCounterDisplay");
            if (videoCounterDisplay != null)
            {
                videoCounterDisplay.Text = $"下一个视频编号: {_settings.VideoCounter:D5}";
            }

             var imageCounterInput = this.FindControl<TextBox>("ImageCounterInput");
            if (imageCounterInput != null)
            {
                imageCounterInput.Text = _settings.ImageCounter.ToString();
            }

            var videoCounterInput = this.FindControl<TextBox>("VideoCounterInput");
            if (videoCounterInput != null)
            {
                 videoCounterInput.Text = _settings.VideoCounter.ToString();
            }
        }

        private string GetSettingsFilePath()
        {
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string appFolder = Path.Combine(appDataPath, "FileRenamerAvalonia");
            Directory.CreateDirectory(appFolder);
            return Path.Combine(appFolder, "settings.json");
        }

        private AppSettings LoadSettings()
        {
            string filePath = GetSettingsFilePath();
            if (File.Exists(filePath))
            {
                try
                {
                    string json = File.ReadAllText(filePath);
                    return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error loading settings: {ex.Message}");
                }
            }
            return new AppSettings();
        }

        private void SaveSettings()
        {
            string filePath = GetSettingsFilePath();
            try
            {
                string json = JsonSerializer.Serialize(_settings, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(filePath, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error saving settings: {ex.Message}");
            }
        }

        private void LoadSettingsAndUpdateUi()
        {
            _settings = LoadSettings();
            UpdateUiCounters();
        }

        private void CounterInput_KeyDown(object? sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter)
            {
                if (sender is TextBox textBox)
                {
                    HandleCounterInputValidation(textBox);
                }
                e.Handled = true;
            }
        }

        private void HandleCounterInputValidation(TextBox textBox)
        {
             bool isImageCounter = textBox.Name == "ImageCounterInput";
            string inputText = textBox.Text ?? "";

            if (int.TryParse(inputText, out int newValue) && newValue >= 1 && newValue <= 99999)
            {
                bool valueChanged = false;
                if (isImageCounter)
                {
                    if (_settings.ImageCounter != newValue)
                    {
                        IncrementAndSetCounter("jpg", newValue);
                        valueChanged = true;
                    }
                }
                else
                {
                    if (_settings.VideoCounter != newValue)
                    {
                        IncrementAndSetCounter("mp4", newValue);
                        valueChanged = true;
                    }
                }

                if (valueChanged)
                {
                    UpdateUiCounters();
                    SaveSettings();
                    Console.WriteLine("Settings saved.");
                }
            }
            else
            {
                if (isImageCounter)
                {
                    textBox.Text = _settings.ImageCounter.ToString();
                }
                else
                {
                    textBox.Text = _settings.VideoCounter.ToString();
                }
                Console.WriteLine("Invalid input. Reverted.");
            }
        }
    }
}
