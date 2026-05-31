#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


MODEL_VERSION = os.getenv("MODEL_VERSION", "local-linear-v1")


def predict(features):
    sepal_length = float(features.get("sepal_length", 0))
    petal_length = float(features.get("petal_length", 0))
    if petal_length < 2.5:
        return "setosa"
    if sepal_length > 6.0:
        return "virginica"
    return "versicolor"


class Handler(BaseHTTPRequestHandler):
    def _json(self, status, body):
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == "/health":
            self._json(200, {"status": "ok", "model_version": MODEL_VERSION})
            return
        self._json(404, {"error": "not_found"})

    def do_POST(self):
        if self.path != "/predict":
            self._json(404, {"error": "not_found"})
            return

        length = int(self.headers.get("content-length", "0"))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
            label = predict(body.get("features", {}))
        except Exception as exc:
            self._json(400, {"error": str(exc)})
            return

        self._json(200, {"prediction": label, "model_version": MODEL_VERSION})


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
