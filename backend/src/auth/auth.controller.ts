
import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService) { }

    @Post('login')
    async login(@Body() req) {
        return this.authService.login(req.email, req.password);
    }

    @Post('register')
    async register(@Body() req) {
        return this.authService.register(req.email, req.password, req.role);
    }
}
