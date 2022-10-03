write('flatclock (powershell版) v20220924
  2022/09/24 UTF-8(BOM)化、$save_x,$save_yのバグ修正、その他改良
  ・MacやLinux上のPowerShellでは動きません。Windowsフォーム使用のため、Windows専用です。
  ・Win7では動きません。Win8は不明
  ・最前面表示ですが、時々前面にならなくなります。また、WMPとWindows標準の「映画＆テレビ」の前面には表示されません。chromeやVLCでは前面に表示されます。
  ・画面保護のために10分置きに、上下左右のランダムな方向に1ピクセル移動します。設定は.ps1ファイルを直接編集すれば変えられます。
  ・スケーリング対応方法不明のため、4kディスプレイなどのスケールされた環境ではジャギーが目立つことがあります。
')
# 履歴
# 2021/11/03 新規
# 2021/11/12 add_paint（paint handler）廃止

# 参考サイト
  # http://kamifuji.dyndns.org/PS-Support/Form/index.html#_0120
  # https://www.kalium.net/image/2017/07/31/powershell%E3%81%8B%E3%82%89%E3%83%9E%E3%83%AB%E3%83%81%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%81%AE%E8%A7%A3%E5%83%8F%E5%BA%A6%E3%82%92%E5%8F%96%E5%BE%97/
  # https://dobon.net/vb/dotnet/form/startposition.html

# 設定部分
 $choco = '#431228'; # 暗い部分の色（こげ茶）
 $mint = '#94FAAE'; # 明るい部分の色（ライトグリーン）
 $trans_key = '#C0FFEE'; # 透明部分のキーカラー（何色でもいいが描画色と被らないようにする）
 $opacity = 0.666; # 透明度（0.000～1.000）
 $siz = 3; # 画面短辺の $siz 分の１の大きさ
 $thk0 = 2; $thk1 = 6; $thk2 = 4; $thk3 = 2.7; # 線の太さ（文字盤/時針/分針/秒針）
 $saverange = 20; # 上下左右にランダムに$saverange % 、1%ずつ移動
 $saveinterval = 600; # 移動する間隔（秒） 1にすると１秒おきに移動 デフォルトは600s＝１０分
 $clockposition = 1; # 0→左側 1→右側

#Load the GDI+ and WinForms Assemblies
 [void][reflection.assembly]::LoadWithPartialName( "System.Windows.Forms")
 [void][reflection.assembly]::LoadWithPartialName( "System.Drawing")

# Create pen and brush objects
 $pen_choco = New-Object Drawing.Pen $choco
 $pen_mint = New-Object Drawing.Pen $mint
 $pen_choco.StartCap = "Round"; $pen_choco.EndCap = "Round"
 $pen_mint.StartCap = "Round"; $pen_mint.EndCap = "Round"

# 画面の解像度取得
 [int]$disp_width = [System.Windows.Forms.Screen]::AllScreens[0].Bounds.Width
 [int]$disp_height = [System.Windows.Forms.Screen]::AllScreens[0].Bounds.Height
 $clock_sq = [Math]::Min($disp_width, $disp_height) / $siz # 時計の正方形のサイズ

# Create a Form
 $form0 = New-Object Windows.Forms.Form
 $form0.Width = $clock_sq * (100 + $saverange) / 100 # デフォルトでは画面縦サイズの３分の１
 $form0.Height = $form0.Width
 if ($clockposition -eq 0) {
 	$form0.Left = 0;
 } else {
 	$form0.Left = $disp_width - $form0.Width;
 }
 $form0.Top = 0; $form0.StartPosition = "Manual";
 $form0.TopMost = $True
 $form0.BackColor = $trans_key
 $form0.TransparencyKey = $trans_key
 $form0.ShowInTaskbar = $False
 $form0.ControlBox = $False
 $form0.FormBorderStyle = "None"
 $form0.Opacity = $opacity # 全体の透明度
 $form0.Text = ''

$PicBox = New-Object System.Windows.Forms.PictureBox; # 可視部分
  $PicBox.Width = $clock_sq * (100 + $saverange) / 100; $PicBox.Height = $PicBox.Width;
 $img = New-Object system.drawing.bitmap([int]($clock_sq * (100 + $saverange) / 100), [int]($clock_sq * (100 + $saverange) / 100));
  # ちらつき防止のために裏で描画してから$PicBoxに反映するための、不可視部分
 $g = $PicBox.createGraphics() # graphicsオブジェクト（線などを描画可能にする）：可視部分
  $gb = [system.drawing.graphics]::FromImage($img) # graphicsオブジェクト：バッファ用不可視部分
 $form0.Controls.Add($PicBox);

$save_x = (Get-Random -Ma 21); $save_y = (Get-Random -Ma 21); # 0～20までのランダムな数値を生成（初期位置）
  $cnt = 0; $doonce = 1; # $doonceは最初の一回だけ$form0を可視化するための変数
  $dx = $clock_sq * $save_x / 100; $dy = $clock_sq * $save_y / 100; # スケールドピクセル単位の画面保護移動位置
  while(1) { # 毎秒呼び出される、時計描画のループ
	$cnt++; if($cnt -ge $saveinterval) { # デフォルトでは10分置きに呼び出される
	  $cnt = 0;
	  $save_x = [Math]::Min([Math]::Max($save_x + (Get-Random -Ma 3) - 1, 0), 20); # %単位の画面保護移動位置（ｘ）
	  $save_y = [Math]::Min([Math]::Max($save_y + (Get-Random -Ma 3) - 1, 0), 20); # %単位の画面保護移動位置（ｙ）
	  $dx = $clock_sq * $save_x / 100; $dy = $clock_sq * $save_y / 100; # スケールドピクセル単位の画面保護移動位置
	}
	$now_time = get-date; # 次の秒ちょうどまで待機するために時刻取得
	 start-sleep -m (1020 - $now_time.millisecond) # 1000だとたまにおかしくなる
	$now_time = get-date; # 時計画像生成のための時刻取得
	 $hour = $now_time.hour; $minu = $now_time.minute; $sec = $now_time.second
	 $minu = $minu + $sec / 60
	 $hour = $hour + $minu / 60
	$gb.Clear($trans_key); # バッファを背景色で塗りつぶし

	$pen_mint.width = $thk0 * $clock_sq / 100     # Set the pen line width # 文字盤目盛描画
	 for ($i = 0; $i -lt 12; $i++) {
	 	$rad = $i * 30 * [math]::pi / 180;
	 	$gb.DrawLine($pen_mint,
	 	 $clock_sq * (0.5 - 0.468 * [math]::sin($rad)) + $dx,
	 	 $clock_sq * (0.5 - 0.468 * [math]::cos($rad)) + $dy,
	 	 $clock_sq * (0.5 - 0.44 * [math]::sin($rad)) + $dx,
	 	 $clock_sq * (0.5 - 0.44 * [math]::cos($rad)) + $dy
	 	)
	 }
	$pen_choco.width = $thk0 * $clock_sq / 100 # 文字盤円描画
	 $gb.DrawEllipse($pen_choco, $clock_sq * 0.03 + $dx, $clock_sq * 0.03 +
	   $dy, $clock_sq * 0.94, $clock_sq * 0.94); # draw an ellipse using rectangle object
	   # 2,3個目のパラメータは座標、4,5個目のパラメータはサイズなので注意

	$pen_choco.width = $thk1 * $clock_sq / 100; $pen_mint.width = $thk1 * $clock_sq / 100; # 時針描画
	$rad = $hour * 30 * [math]::pi / 180;
	$gb.DrawLine($pen_mint,
	 $clock_sq * (0.5 + 0.23 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.23 * [math]::cos($rad)) + $dy,
	 $clock_sq * (0.5 + 0.25 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.25 * [math]::cos($rad)) + $dy
	)
	$gb.DrawLine($pen_choco,
	 $clock_sq * (0.5 - 0.03 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 + 0.03 * [math]::cos($rad)) + $dy,
	 $clock_sq * (0.5 + 0.18 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.18 * [math]::cos($rad)) + $dy
	)

	$pen_choco.width = $thk2 * $clock_sq / 100; $pen_mint.width = $thk2 * $clock_sq / 100; # 分針描画
	$rad = $minu * 6 * [math]::pi / 180;
	$gb.DrawLine($pen_mint,
	 $clock_sq * (0.5 + 0.32 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.32 * [math]::cos($rad)) + $dy,
	 $clock_sq * (0.5 + 0.37 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.37 * [math]::cos($rad)) + $dy
	)
	$gb.DrawLine($pen_choco,
	 $clock_sq * (0.5 - 0.05 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 + 0.05 * [math]::cos($rad)) + $dy,
	 $clock_sq * (0.5 + 0.29 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.29 * [math]::cos($rad)) + $dy
	)
	$pen_mint.width = $thk3 * $clock_sq / 100; # 秒針描画
	$rad = $sec * 6 * [math]::pi / 180;
	$gb.DrawLine($pen_mint,
	 $clock_sq * (0.5 + 0.47 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.47 * [math]::cos($rad)) + $dy,
	 $clock_sq * (0.5 + 0.471 * [math]::sin($rad)) + $dx,
	 $clock_sq * (0.5 - 0.471 * [math]::cos($rad)) + $dy
	)
	$g.DrawImage($img, 0, 0); # バッファの不可視イメージを可視部分にコピー描画
	if ($doonce) {$doonce = 0; $form0.show();}
  }
