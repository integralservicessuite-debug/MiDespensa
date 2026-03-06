import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
export declare class LocationGateway implements OnGatewayConnection, OnGatewayDisconnect {
    server: Server;
    handleConnection(client: Socket): void;
    handleDisconnect(client: Socket): void;
    handleSubscribe(orderId: string, client: Socket): {
        event: string;
        data: string;
    };
    handleUpdateLocation(data: {
        orderId: string;
        lat: number;
        lng: number;
    }): void;
}
