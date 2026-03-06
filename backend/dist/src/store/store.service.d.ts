import { OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
export declare class StoreService implements OnModuleInit {
    private prisma;
    constructor(prisma: PrismaService);
    onModuleInit(): Promise<void>;
    getSettings(): Promise<{
        id: string;
        updatedAt: Date;
        name: string;
        email: string;
        phone: string;
        address: string;
        hours: string | null;
        logoUrl: string;
    } | null>;
}
