package flixel.addons.display;

import flixel.FlxStrip;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxRect;
import flixel.util.FlxSpriteUtil;

/**
 * Tiled sprite which displays repeated and clipped graphic.
 * @author Zaphod
 * @since  2.1.0
 */
class FlxTiledSprite extends FlxStrip
{
	/**
	 * The x-offset of the texture
	 */
	public var scrollX(default, set):Float = 0;
	
	/**
	 * The y-offset of the texture.
	 */
	public var scrollY(default, set):Float = 0;
	
	/**
	 * Repeat texture on x axis. Default is true
	 */
	public var repeatX(default, set):Bool = true;
	
	/**
	 * Repeat texture on y axis. Default is true
	 */
	public var repeatY(default, set):Bool = true;
	
	/**
	 * Helper sprite, which does actual rendering in blit render mode.
	 */
	var renderSprite:FlxSprite;
	
	var regen:Bool = true;
	
	var graphicVisible:Bool = true;
	
	public function new(?graphic:FlxGraphicAsset, width:Float, height:Float, repeatX = true, repeatY = true)
	{
		super();
		
		repeat = true;
		
		indices[0] = 0;
		indices[1] = 1;
		indices[2] = 2;
		indices[3] = 2;
		indices[4] = 3;
		indices[5] = 0;
		
		uvtData[0] = 0;
		uvtData[1] = 0;
		uvtData[2] = 1;
		uvtData[3] = 0;
		uvtData[4] = 1;
		uvtData[5] = 1;
		uvtData[6] = 0;
		uvtData[7] = 1;
		
		vertices[0] = 0;
		vertices[1] = 0;
		vertices[2] = width;
		vertices[3] = 0;
		vertices[4] = width;
		vertices[5] = height;
		vertices[6] = 0;
		vertices[7] = height;
		
		this.width = width;
		this.height = height;
		
		this.repeatX = repeatX;
		this.repeatY = repeatY;
		
		if (graphic != null)
			loadGraphic(graphic);
	}
	
	override function destroy():Void
	{
		renderSprite = FlxDestroyUtil.destroy(renderSprite);
		super.destroy();
	}
	
	override function loadGraphic(graphic, animated = false, width = 0, height = 0, unique = false, ?key:String):FlxSprite
	{
		this.graphic = FlxG.bitmap.add(graphic);
		return this;
	}
	
	public function loadFrame(frame:FlxFrame):FlxTiledSprite
	{
		graphic = FlxGraphic.fromFrame(frame);
		return this;
	}

	override function set_clipRect(Value:FlxRect):FlxRect
	{
		if (Value != clipRect)
			regen = true;

		return super.set_clipRect(Value);
	}

	override function set_graphic(Value:FlxGraphic):FlxGraphic
	{
		if (graphic != value)
			regen = true;
		
		return super.set_graphic(value);
	}
	
	function regenGraphic():Void
	{
		if (!regen || graphic == null)
			return;
		
		if (FlxG.renderBlit)
		{
			updateRenderSprite();
		}
		else
		{
			updateVerticesData();
		}
		
		regen = false;
	}
	
	override function draw():Void
	{
		if (regen)
			regenGraphic();
		
		if (graphicVisible)
		{
			if (FlxG.renderBlit)
			{
				renderSprite.x = x;
				renderSprite.y = y;
				renderSprite.scrollFactor.set(scrollFactor.x, scrollFactor.y);
				renderSprite._cameras = _cameras;
				renderSprite.draw();
			}
			else
			{
				super.draw();
			}
		}
		
		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawDebug();
		#end
	}
	
	#if FLX_DEBUG
	/**
	 * Copied exactly from `FlxObject`, to avoid any future changes to `FlxStrip`'s debug drawing
	 */
	override function drawDebug()
	{
		if (ignoreDrawDebug)
			return;
		
		final drawPath = path != null && !path.ignoreDrawDebug;
		
		for (camera in getCamerasLegacy())
		{
			drawDebugOnCamera(camera);
			
			if (drawPath)
			{
				path.drawDebugOnCamera(camera);
			}
		}
	}
	#end
	
	function updateRenderSprite():Void
	{
		graphicVisible = true;
		
		if (renderSprite == null)
			renderSprite = new FlxSprite();
		
		final drawRect = getDrawRect();
		drawRect.x = Std.int(drawRect.x);
		drawRect.y = Std.int(drawRect.y);
		drawRect.width = Std.int(drawRect.width);
		drawRect.height = Std.int(drawRect.height);
		//TODO: rect.int() or smth
		
		if (drawRect.width * drawRect.height == 0)
		{
			graphicVisible = false;
			drawRect.put();
			return;
		}
		
		if (renderSprite.width != drawRect.width || renderSprite.height != drawRect.height)
		{
			renderSprite.makeGraphic(Std.int(drawRect.width), Std.int(drawRect.height), FlxColor.TRANSPARENT, true);
		}
		else
		{
			renderSprite.pixels.fillRect(renderSprite.pixels.rect, FlxColor.TRANSPARENT);
		}
		
		FlxSpriteUtil.flashGfx.clear();
		
		if (scrollX != 0 || scrollY != 0)
		{
			_matrix.identity();
			_matrix.tx = Math.round(scrollX);
			_matrix.ty = Math.round(scrollY);
			FlxSpriteUtil.flashGfx.beginBitmapFill(graphic.bitmap, _matrix);
		}
		else
		{
			FlxSpriteUtil.flashGfx.beginBitmapFill(graphic.bitmap);
		}
		
		FlxSpriteUtil.flashGfx.drawRect(drawRect.x, drawRect.y, drawRect.width, drawRect.height);
		renderSprite.pixels.draw(FlxSpriteUtil.flashGfxSprite, null, colorTransform);
		FlxSpriteUtil.flashGfx.clear();
		renderSprite.dirty = true;
	}
	
	function updateVerticesData():Void
	{
		if (graphic == null)
			return;
		
		final frame:FlxFrame = graphic.imageFrame.frame;
		graphicVisible = true;

		var rectX:Float = (repeatX ? 0 : scrollX);
		rectX = FlxMath.bound(rectX, 0, width);
		if (clipRect != null) rectX += clipRect.x;

		var rectWidth:Float = (repeatX ? rectX + width : scrollX + frame.sourceSize.x);
		if (clipRect != null) rectWidth = FlxMath.bound(rectWidth, clipRect.x, clipRect.x + clipRect.width);

		// Texture coordinates (UVs)
		var rectUX:Float = (rectX - scrollX) / frame.sourceSize.x;
		var rectVX:Float = rectUX + (rectWidth-rectX) / frame.sourceSize.x;

		vertices[0] = rectX;
		vertices[2] = rectWidth;
		vertices[4] = rectWidth;
		vertices[6] = rectX;

		uvtData[0] = rectUX;
		uvtData[2] = rectVX;
		uvtData[4] = rectVX;
		uvtData[6] = rectUX;

		var rectY:Float = (repeatY ? 0 : scrollY);
		rectY = FlxMath.bound(rectY, 0, height);
		if (clipRect != null) rectY += clipRect.y;

		var rectHeight:Float = (repeatY ? rectY + height : scrollY + frame.sourceSize.y);
		if (clipRect != null) rectHeight = FlxMath.bound(rectHeight, clipRect.y, clipRect.y + clipRect.height);

		// Texture coordinates (UVs)
		var rectUY:Float = (rectY - scrollY) / frame.sourceSize.y;
		var rectVY:Float = rectUY + (rectHeight-rectY) / frame.sourceSize.y;

		vertices[1] = rectY;
		vertices[3] = rectY;
		vertices[5] = rectHeight;
		vertices[7] = rectHeight;

		uvtData[1] = rectUY;
		uvtData[3] = rectUY;
		uvtData[5] = rectVY;
		uvtData[7] = rectVY;
	}

	override function set_width(Width:Float):Float
	{
		if (value <= 0)
			return value;
		
		if (value != width)
			regen = true;
		
		return super.set_width(value);
	}
	
	override function set_height(value:Float):Float
	{
		if (value <= 0)
			return value;
		
		if (value != height)
			regen = true;
		
		return super.set_height(value);
	}
	
	function set_scrollX(value:Float):Float
	{
		if (value != scrollX)
			regen = true;
		
		return scrollX = value;
	}
	
	function set_scrollY(value:Float):Float
	{
		if (value != scrollY)
			regen = true;
		
		return scrollY = value;
	}
	
	function set_repeatX(value:Bool):Bool
	{
		if (value != repeatX)
			regen = true;
		
		return repeatX = value;
	}
	
	function set_repeatY(value:Bool):Bool
	{
		if (value != repeatY)
			regen = true;
		
		return repeatY = value;
	}
}
