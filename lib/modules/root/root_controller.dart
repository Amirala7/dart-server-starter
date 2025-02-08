import 'package:shelf/shelf.dart';

class RootController {
  Future<Response> get(Request request) async {
    return Response.ok(
      '''
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body {
              background-color: black;
              color: white;
              height: 100vh;
              margin: 0;
              display: flex;
              justify-content: center;
              align-items: center;
              font-family: Arial, sans-serif;
            }
            h1 {
              font-size: 4rem;
              font-weight: bold;
            }
          </style>
        </head>
        <body>
          <h1>CUSTOM LABS</h1>
        </body>
      </html>
      ''',
      headers: {'content-type': 'text/html'},
    );
  }
}