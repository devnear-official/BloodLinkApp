import express from "express";
import "dotenv/config";
import path from "path";
import { connectDB } from "./config/db.ts";
import { JWT_SECRET } from "./config/auth.ts";
import { createServer } from "http";
import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import cors from "cors";
import { initWebPush } from "./utils/webpush.ts";

const trustedOrigins = new Set([
  "https://bloodlink-frontend-e0jx.onrender.com",
  "https://cu-blood.vercel.app",
  "https://org-frontend.onrender.com",
  "https://ais-dev-wof6l3j7ywxzln3dfbloc6-171726856505.asia-southeast1.run.app",
]);

function isAllowedOrigin(origin?: string) {
  if (!origin) return true; // Native clients do not send an Origin header.
  if (trustedOrigins.has(origin)) return true;
  try {
    const url = new URL(origin);
    return ["localhost", "127.0.0.1"].includes(url.hostname);
  } catch {
    return false;
  }
}

// Import routes
import authRoutes from "./routes/auth.ts";
import requestRoutes from "./routes/requests.ts";
import userRoutes from "./routes/users.ts";
import directRequestRoutes from "./routes/directRequests.ts";
import notificationRoutes from "./routes/notifications.ts";

async function startServer() {
  const app = express();
  const PORT = Number(process.env.PORT) || 3000;
  
  // Enable CORS for frontend running on different ports locally
  app.use(cors({
    origin: (origin, callback) => callback(null, isAllowedOrigin(origin)),
    credentials: true,
  }));
  app.use(express.json());
  
  const httpServer = createServer(app);
  const io = new Server(httpServer, {
    cors: {
      origin: (origin, callback) => callback(null, isAllowedOrigin(origin)),
      methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
      credentials: true,
    },
  });

  app.set("io", io);

  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (token) {
      jwt.verify(token, JWT_SECRET, (err: any, decoded: any) => {
        if (err) return next(new Error("Unauthorized"));
        socket.data.user = decoded;
        next();
      });
    } else {
      next();
    }
  });

  io.on("connection", (socket) => {
    console.log("A user connected:", socket.id);
    
    if (socket.data.user) {
      // Join a room with their user ID so we can target them
      socket.join(socket.data.user.id);
      console.log(`User ${socket.data.user.id} joined their room`);
    }

    socket.on("disconnect", () => {
      console.log("User disconnected:", socket.id);
    });
  });

  // Connect to MongoDB
  await connectDB();
  await initWebPush();

  // API routes
  app.use("/api/auth", authRoutes);
  app.use("/api/requests", requestRoutes);
  app.use("/api/users", userRoutes);
  app.use("/api/direct-requests", directRequestRoutes);
  app.use("/api/notifications", notificationRoutes);

  app.get("/api/health", (req, res) => {
    res.json({ status: "ok" });
  });

  if (process.env.NODE_ENV === "production") {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  httpServer.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
