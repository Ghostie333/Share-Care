using System;
using System.Net;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using Share_Care.Controllers;
using Share_Care.Models.Requests;
using Share_Care.models;
using Share_Care.Services;
using Xunit;

namespace Share_Care.Tests.Controllers
{
    public class UserLoginControllerTests
    {
        [Fact]
        public async Task Login_WhenCredentialsInvalid_ReturnsUnauthorized()
        {
            var logger = new Mock<ILogger<UserLoginController>>();
            var loginService = new Mock<ILoginService>();

            loginService
                .Setup(s => s.ValidateCredentialsAsync("e", "p", It.IsAny<CancellationToken>()))
                .ReturnsAsync((UserData?)null);

            var controller = new UserLoginController(logger.Object, loginService.Object)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
            };

            var result = await controller.Login(new LoginRequest { Email = "e", Password = "p" }, CancellationToken.None);

            var unauthorized = Assert.IsType<UnauthorizedObjectResult>(result);
            Assert.Equal((int)HttpStatusCode.Unauthorized, unauthorized.StatusCode);
        }

        [Fact]
        public async Task Login_WhenJwtConfigMissing_Returns500()
        {
            var logger = new Mock<ILogger<UserLoginController>>();

            var loginService = new Mock<ILoginService>();

            var user = new UserData { UserId = "1", Email = "e" };
            loginService
                .Setup(s => s.ValidateCredentialsAsync("e", "p", It.IsAny<CancellationToken>()))
                .ReturnsAsync(user);

            loginService
                .Setup(s => s.GenerateJwtToken(user, out It.Ref<System.DateTime>.IsAny))
                .Throws<InvalidOperationException>();

            var controller = new UserLoginController(logger.Object, loginService.Object)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
            };

            var result = await controller.Login(new LoginRequest { Email = "e", Password = "p" }, CancellationToken.None);

            var obj = Assert.IsType<ObjectResult>(result);
            Assert.Equal(StatusCodes.Status500InternalServerError, obj.StatusCode);
        }
    }
}
