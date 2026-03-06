import {
  WebSocketGateway,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ cors: true })
export class LocationGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  handleConnection(client: Socket) {
    console.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    console.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('subscribeToOrder')
  handleSubscribe(
    @MessageBody() orderId: string,
    @ConnectedSocket() client: Socket,
  ) {
    const roomName = `order_${orderId}`;
    client.join(roomName);
    console.log(`Client ${client.id} joined room ${roomName}`);
    return { event: 'subscribed', data: roomName };
  }

  @SubscribeMessage('updateLocation')
  handleUpdateLocation(
    @MessageBody() data: { orderId: string; lat: number; lng: number },
  ) {
    const roomName = `order_${data.orderId}`;
    this.server.to(roomName).emit('locationUpdate', {
      lat: data.lat,
      lng: data.lng,
      timestamp: new Date().toISOString(),
    });
  }

  @SubscribeMessage('sendChatMessage')
  handleChatMessage(
    @MessageBody() data: { orderId: string; senderRole: string; text: string },
  ) {
    const roomName = `order_${data.orderId}`;
    this.server.to(roomName).emit('chatMessage', {
      ...data,
      timestamp: new Date().toISOString(),
    });
  }

  // Generic method to simulate Push Notifications via WebSockets
  sendPushNotification(title: string, body: string, topic?: string) {
    this.server.emit('pushNotification', { title, body, topic });
  }
}
