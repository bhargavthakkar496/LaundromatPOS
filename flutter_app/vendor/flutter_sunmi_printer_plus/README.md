# flutter_sunmi_printer_plus
This is plugin inspired by [SunmiPrinterDemo](https://github.com/shangmisunmi/SunmiPrinterDemo)
## Platform Support
This plugin works only on android

## Usage

To use this plugin, add `flutter_sunmi_printer_plus` as a dependency in your pubspec.yaml file

## What this package do
- [x] Print text with style (font size,bold or not,alignment,..)
- [x] Print image (you can set alignment)
- [x] Print table
- [x] Print qrcode (with stye)
- [x] Print barcode(with style)
- [x] Jump n-lines 
- [x] Cut paper  

## Example

Import the library.

```dart
import 'package:flutter_sunmi_printer_plus/flutter_sunmi_printer_plus.dart';
```

Then invoke the static `initPrinter` method to initiate sunmi printer .

```dart

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      try {
        isConnected = await SunmiPrinter.initPrinter() ?? false;
        setState(() {});
      } catch (err) {
        errorMessage = err.toString();
      }
      setState(() {});
    });
  }
```


#### Print text
```dart
      await SunmiPrinter.printText(
                          content: "Test String",
                          style: SunmiStyle(
                              fontSize: 20,
                              isUnderLine: true,
                              bold: false,
                              align: SunmiPrintAlign.LEFT));
```
#### Print image
```dart
 await SunmiPrinter.printImage(image: bytes, align: SunmiPrintAlign.CENTER); // bytes as Uint8List
```

#### Print table
```dart
 await SunmiPrinter.printTable(cols: [
                  ColumnMaker(text:"test#1" ,align:SunmiPrintAlign.LEFT ,width:5),
                   ColumnMaker(text:"test#2" ,align:SunmiPrintAlign.LEFT ,width: 5),
                ]);  
```

#### Print barcode
```dart
await SunmiPrinter.printBarCode(data: "1234567890",height: 50,width: 2,textPosition: SunmiBarcodeTextPos.TEXT_UNDER,barcodeType:SunmiBarcodeType.CODE128,align:SunmiPrintAlign.CENTER );   
```

#### Print qrcode
```dart
await SunmiPrinter.printQr(data: "https://twitter.com/wojoodtech",align:SunmiPrintAlign.CENTER,size: 5);          
```


See the `main.dart` in the `example` for a complete example.


