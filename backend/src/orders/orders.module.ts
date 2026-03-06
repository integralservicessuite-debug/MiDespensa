import { Module } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { OrdersController } from './orders.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { LocationModule } from '../location/location.module';

@Module({
  imports: [PrismaModule, LocationModule],
  controllers: [OrdersController],
  providers: [OrdersService],
})
export class OrdersModule { }
