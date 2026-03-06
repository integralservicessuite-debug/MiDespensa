import { StoreService } from './store.service';
export declare class StoreController {
    private readonly storeService;
    constructor(storeService: StoreService);
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
