using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Models.Requests;

public sealed class UserUpdateRequest
{
    public string? Email { get; set; } 
    public string? FirstName { get; set; } 
    public string? LastName { get; set; }
    public string? Birthday { get; set; }
    public string? PhoneNumber { get; set; }
    public string? City { get; set; }
    public string? PostalCode { get; set; }
}