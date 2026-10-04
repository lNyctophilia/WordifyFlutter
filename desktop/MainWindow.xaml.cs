using System;
using System.IO;
using System.Windows;
using Microsoft.Web.WebView2.Core;

namespace Wordify;

public partial class MainWindow : Window
{
    private const string TargetUrl = "https://lnyctophilia.github.io/WordifyFlutter";

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            string userDataDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Wordify"
            );

            var env = await CoreWebView2Environment.CreateAsync(null, userDataDir);
            await webView.EnsureCoreWebView2Async(env);

            webView.CoreWebView2.Settings.IsStatusBarEnabled = false;
            webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = true;
            webView.CoreWebView2.Settings.IsZoomControlEnabled = true;

            webView.CoreWebView2.NavigationCompleted += CoreWebView2_NavigationCompleted;
            webView.CoreWebView2.NewWindowRequested += CoreWebView2_NewWindowRequested;

            webView.Source = new Uri(TargetUrl);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"WebView başlatılamadı: {ex.Message}",
                "Wordify Hata",
                MessageBoxButton.OK,
                MessageBoxImage.Error
            );
        }
    }

    private void CoreWebView2_NavigationCompleted(object? sender, CoreWebView2NavigationCompletedEventArgs e)
    {
        LoadingOverlay.Visibility = Visibility.Collapsed;
        Title = "Wordify";
    }

    private void CoreWebView2_NewWindowRequested(object? sender, CoreWebView2NewWindowRequestedEventArgs e)
    {
        // Allow popups (like Google Auth) to open in a popup window
        e.Handled = false;
    }
}