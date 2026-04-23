import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_sunmi_printer_plus/flutter_sunmi_printer_plus.dart';
import 'package:flutter_sunmi_printer_plus/sunmi_style.dart';
import 'package:flutter_sunmi_printer_plus/enums.dart';
import 'package:flutter_sunmi_printer_plus/column_maker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String errorMessage = '';
  int? sunmiPrinter;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      try {
        isConnected = await SunmiPrinter.initPrinter() ?? false;
        // print("printer is connected:${isConnected}");

        setState(() {});
      } catch (err) {
        errorMessage = err.toString();
      }
      setState(() {});
    });
  }

  Future<Uint8List> readFileBytes(String path) async {
    try {
      ByteData fileData = await rootBundle.load(path);
      Uint8List fileUnit8List = fileData.buffer
          .asUint8List(fileData.offsetInBytes, fileData.lengthInBytes);
      return fileUnit8List;
    } catch (err) {
      rethrow;
    }
  }

  Future<Uint8List> _getImageFromAsset(String iconPath) async {
    return await readFileBytes(iconPath);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: const Text("print Text"),
                    onPressed: () async {
                      try{
                      await SunmiPrinter.printText(
                          content: "Test String",
                          style: SunmiStyle(
                              fontSize: 20,
                              isUnderLine: true,
                              bold: false,
                              align: SunmiPrintAlign.LEFT));
                      await SunmiPrinter.lineWrap(1);
                      await SunmiPrinter.printText(
                          content: "Test String #2",
                          style: SunmiStyle(
                              fontSize: 24,
                              isUnderLine: false,
                              bold: true,
                              align: SunmiPrintAlign.CENTER));
                    await SunmiPrinter.feedPaper();
                      }catch(err){
                           errorMessage = err.toString();
                           setState(() {});
                      }
                    },
                  ),
                  
                         ElevatedButton(
                    child: const Text("الطباعة بالعربي"),
                    onPressed: () async {
                      try{
                     
                              await SunmiPrinter.printText(
                          content: "نص تجريبي",
                          style: SunmiStyle(
                              fontSize: 24,
                              isUnderLine: false,
                              bold: true,
                              align: SunmiPrintAlign.RIGHT));
                await SunmiPrinter.lineWrap(1);
                        await SunmiPrinter.printText(
                          content: "نص تجريبي",
                          style: SunmiStyle(
                              fontSize: 24,
                              isUnderLine: false,
                              bold: true,
                              align: SunmiPrintAlign.CENTER));
                await SunmiPrinter.lineWrap(1);
                        await SunmiPrinter.printText(
                          content: "نص تجريبي",
                          style: SunmiStyle(
                              fontSize: 24,
                              isUnderLine: false,
                              bold: true,
                              align: SunmiPrintAlign.LEFT));
                await SunmiPrinter.lineWrap(1);

                    await SunmiPrinter.feedPaper();
                    await SunmiPrinter.cutPaper();
                   }catch(err){
                         errorMessage = err.toString();
      setState(() {});
                    }
                    },

                  ),
                  
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: const Text("print Image"),
                    onPressed: () async {
                      try{
                    Uint8List bytes = await _getImageFromAsset('assets/print_logo.jpeg');
                      await SunmiPrinter.printImage(image: bytes, align: SunmiPrintAlign.CENTER);
                    await SunmiPrinter.lineWrap(1);
                    await SunmiPrinter.feedPaper();
                    await SunmiPrinter.cutPaper();
                      }catch(err){
                   errorMessage = err.toString();
                   setState(() {});
                      }
                    },
                  ),
                  
                         ElevatedButton(
                    child: const Text("print Qr code"),
                    onPressed: () async {
                     try{
                await SunmiPrinter.printQr(data: "https://twitter.com/wojoodtech",align:SunmiPrintAlign.CENTER,size: 5);          
                await SunmiPrinter.lineWrap(1);
                await SunmiPrinter.feedPaper();
                await SunmiPrinter.cutPaper();
                       }catch(err){
                   errorMessage = err.toString();
                   setState(() {});
                      
                     }
                    },
                  ),
                
                  
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                          ElevatedButton(
                    child: const Text("print barcode"),
                    onPressed: () async {
                     try{
                await SunmiPrinter.printBarCode(data: "1234567890",height: 50,width: 2,textPosition: SunmiBarcodeTextPos.TEXT_UNDER,barcodeType:SunmiBarcodeType.CODE128,align:SunmiPrintAlign.CENTER );   
                await SunmiPrinter.lineWrap(1);
                await SunmiPrinter.feedPaper();
                await SunmiPrinter.cutPaper();
                 }catch(err){
                   errorMessage = err.toString();
                   setState(() {});
                      }
                    },
                  ),
                             ElevatedButton(
                    child: const Text("print table"),
                    onPressed: () async {
                      try{
                await SunmiPrinter.printTable(cols: [
                  ColumnMaker(text:"test#1" ,align:SunmiPrintAlign.LEFT ,width:5),
                   ColumnMaker(text:"test#2" ,align:SunmiPrintAlign.LEFT ,width: 5),
                ]);  
                 await SunmiPrinter.printTable(cols: [
                  ColumnMaker(text:"test#3" ,align:SunmiPrintAlign.LEFT ,width: 5),
                   ColumnMaker(text:"test#4" ,align:SunmiPrintAlign.LEFT ,width: 5),
                ]);  
                await SunmiPrinter.lineWrap(1);
                await SunmiPrinter.feedPaper();
                await SunmiPrinter.cutPaper();
                       }catch(err){
                   errorMessage = err.toString();
                   setState(() {});
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height:15,),
              Text("Printer is connect :${SunmiPrinter.isConnected}"),
              Text("Error:$errorMessage")
            ],
          ),
        ),
      ),
    );
  }
}
