import { Module } from '@nestjs/common';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { ProductsModule } from './products/products.module';
import { PrismaModule } from './prisma/prisma.module';
import { OrdersModule } from './orders/orders.module';
import { StoreModule } from './store/store.module';
import { LocationModule } from './location/location.module';

@Module({
  imports: [
    ServeStaticModule.forRoot({
      rootPath: join(process.cwd(), 'public'),
      serveRoot: '/api/v1/assets',
    }),
    AuthModule,
    ProductsModule,
    PrismaModule,
    OrdersModule,
    StoreModule,
    LocationModule
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule { }
