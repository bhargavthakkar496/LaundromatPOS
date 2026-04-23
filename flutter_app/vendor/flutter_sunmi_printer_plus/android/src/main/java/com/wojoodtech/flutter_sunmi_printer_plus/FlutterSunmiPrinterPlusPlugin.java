package com.wojoodtech.flutter_sunmi_printer_plus;

import android.content.Context;
import androidx.annotation.NonNull;
import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import com.wojoodtech.flutter_sunmi_printer_plus.utils.SunmiPrintHelper;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import org.json.JSONArray;
import org.json.JSONObject;


/** FlutterSunmiPrinterPlusPlugin */
public class FlutterSunmiPrinterPlusPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private Context context;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_sunmi_printer_plus");
    context=flutterPluginBinding.getApplicationContext();
    channel.setMethodCallHandler(this);

  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
     if (call.method.equals("initPrinter")) {
       SunmiPrintHelper.getInstance().initSunmiPrinterService(context);
       SunmiPrintHelper.getInstance().initPrinter();
       if(SunmiPrintHelper.getInstance().sunmiPrinter==SunmiPrintHelper.FoundSunmiPrinter){
         // result.success(SunmiPrintHelper.getInstance().sunmiPrinter);
         result.success(true);
       }else {
         result.success(false);

       }
     }
    else if(call.method.equals("printText")){
      String content=call.argument("content").toString();
      float size=  Float.parseFloat(call.argument("size").toString());
      boolean isBold=call.argument("isBold");
      boolean isUnderLine=call.argument("isUnderLine");
      int align=call.argument("align");
      String testFont = null;
      SunmiPrintHelper.getInstance().setAlign(align);
      SunmiPrintHelper.getInstance().printText(content, size, isBold, isUnderLine, testFont);
      result.success("success");
    }else if(call.method.equals("feedPaper")){
      SunmiPrintHelper.getInstance().feedPaper();
      result.success("success");

    }
    else if(call.method.equals("isConnected")){
      int isConnected=  SunmiPrintHelper.getInstance().sunmiPrinter ;
      if(isConnected==SunmiPrintHelper.FoundSunmiPrinter){
        result.success(true);
      }else{
        result.success(false);
      }
    }else if(call.method.equals("setAlignment")){

      SunmiPrintHelper.getInstance().setAlign(call.argument("align"));
      result.success(true);

    }else if(call.method.equals("lineWrap")){

      int lineNumber=call.argument("lineNumber");
      SunmiPrintHelper.getInstance().lineWrap(lineNumber);
      result.success(true);

    }else if(call.method.equals("printImage")){

      byte[] bytes = call.argument("image");
      int align=call.argument("align");
      Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
      SunmiPrintHelper.getInstance().setAlign(align);
      SunmiPrintHelper.getInstance().printBitmap(bitmap, 0);
      result.success(true);

    }else if(call.method.equals("printQr")){

      String data=call.argument("data");
      int moduleSize=call.argument("size");
      int errorLevel=call.argument("errorLevel");
      int align=call.argument("align");
      SunmiPrintHelper.getInstance().setAlign(align);
      SunmiPrintHelper.getInstance().printQr(data,moduleSize,errorLevel);
      result.success(true);

    }else if (call.method.equals("printBarCode")){

      String data=call.argument("data");
      int symbology=call.argument("symbology");
      int height=call.argument("height");
      int width=call.argument("width");
      int textPosition=call.argument("textPosition");
      int align=call.argument("align");
      SunmiPrintHelper.getInstance().setAlign(align);
      SunmiPrintHelper.getInstance().printBarCode(data,symbology,height,width,textPosition);
      result.success(true);

    }else if(call.method.equals("printTable")){

      String colsStr = call.argument("cols");
      try {
        JSONArray cols = new JSONArray(colsStr);
        String[] colsText = new String[cols.length()];
        int[] colsWidth = new int[cols.length()];
        int[] colsAlign = new int[cols.length()];
        for (int i = 0; i < cols.length(); i++) {
          JSONObject col = cols.getJSONObject(i);
          String textColumn = col.getString("text");
          int widthColumn = col.getInt("width");
          int alignColumn = col.getInt("align");
          colsText[i] = textColumn;
          colsWidth[i] = widthColumn;
          colsAlign[i] = alignColumn;
        }

        SunmiPrintHelper.getInstance().printTable(colsText, colsWidth, colsAlign);
        result.success(true);
      } catch (Exception err) {
        Log.d("SunmiPrinter", err.getMessage());
      }
    }
    else if(call.method.equals("cutPaper")){
       SunmiPrintHelper.getInstance().cutpaper();
       result.success(true);
    }
    else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
}
