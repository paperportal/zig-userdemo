pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn containsClick(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and px <= (self.x + self.w) and py >= self.y and py <= (self.y + self.h);
    }
};

pub const Tap = struct {
    x: i32,
    y: i32,
};

